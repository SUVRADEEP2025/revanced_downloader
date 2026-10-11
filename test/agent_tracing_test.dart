import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rd_manager/main.dart' show kSentryDsn;
import 'package:rd_manager/services/agent_tracing.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Decorates the SDK's real transport so the test can see what actually
/// leaves the app. `HttpTransport` returns [SentryId.empty] on any HTTP
/// error or network failure, and an id (or `null` when the response body
/// carries none) on HTTP 200 — so a non-zero [failureCount] means Sentry
/// refused the data.
class _RecordingTransport implements Transport {
  _RecordingTransport(this._inner);

  final Transport _inner;
  int sendCount = 0;
  int failureCount = 0;
  final List<String> acceptedIds = [];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    final id = await _inner.send(envelope);
    sendCount++;
    if (id == SentryId.empty()) {
      failureCount++;
    } else if (id != null) {
      // Sentry echoed the event id back: the envelope was ingested.
      acceptedIds.add(id.toString());
    }
    return id;
  }
}

void main() {
  late SentryOptions options;
  late _RecordingTransport transport;

  /// Span name -> snapshot taken when the SDK handed the span to the sender.
  final spans = <String, Map<String, Object?>>{};

  setUpAll(() async {
    await Sentry.init((opts) {
      opts.dsn = kSentryDsn;
      opts.tracesSampleRate = 1.0;
      opts.environment = 'test';
      opts.debug = true;
      opts.diagnosticLevel = SentryLevel.debug;
      opts.beforeSendSpan = (span, hint) {
        spans[span.name] = <String, Object?>{
          'status': span.status.name,
          'parent': span.parentSpan?.name,
          'attributes': <String, Object?>{
            for (final entry in span.attributes.entries)
              entry.key: entry.value.value,
          },
        };
      };
      options = opts;
    });

    // The client reads `options.transport` on every send, so wrapping it
    // after init observes every envelope the SDK dispatches.
    transport = _RecordingTransport(options.transport);
    options.transport = transport;
  });

  tearDownAll(() async {
    // Let in-flight span envelopes land before reporting the tally: wait
    // until nothing new has been sent for 3 seconds (max 15s).
    var unchangedRuns = 0;
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline) && unchangedRuns < 6) {
      final before = transport.sendCount;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      unchangedRuns = transport.sendCount == before ? unchangedRuns + 1 : 0;
    }
    debugPrint(
      'Sentry ingest: ${transport.sendCount} envelope(s) sent, '
      '${transport.failureCount} rejected, '
      'event ids echoed back: ${transport.acceptedIds}',
    );
    await Sentry.close();
  });

  Future<void> waitForSend({Duration timeout = const Duration(seconds: 20)}) async {
    final deadline = DateTime.now().add(timeout);
    while (transport.sendCount == 0 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> waitForSpan(
    String name, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!spans.containsKey(name) && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Object? attr(String spanName, String key) {
    final snapshot = spans[spanName];
    expect(snapshot, isNotNull, reason: 'span "$spanName" was never captured');
    return (snapshot!['attributes'] as Map<String, Object?>)[key];
  }

  test(
    'agent run emits gen_ai spans grouped by one conversation id',
    () async {
      final answer = await AgentTracing.conversation(
        id: 'conv_test_abc123',
        userId: 'user-42',
        email: 'dev@example.com',
        body: () {
          return AgentTracing.agent(
            agentName: 'ReVance Assistant',
            run: (agent) async {
              final answer = await AgentTracing.chat(
                provider: 'openai',
                model: 'gpt-4o',
                systemInstructions: 'You are a ReVance expert.',
                inputMessages: [
                  {
                    'role': 'user',
                    'parts': [
                      {
                        'type': 'text',
                        'content': 'Which patches are safe to apply?',
                      },
                    ],
                  },
                ],
                temperature: 0.2,
                run: (chat) async {
                  chat.setResponse(
                    text: 'All verified patches are safe.',
                    model: 'gpt-4o-2024-08-06',
                    finishReasons: ['stop'],
                  );
                  chat.setUsage(inputTokens: 120, outputTokens: 24);
                  return 'All verified patches are safe.';
                },
              );

              final repos = await AgentTracing.tool(
                toolName: 'list_repos',
                arguments: {'query': 'revanced'},
                run: (span) async {
                  span.setToolResult(['revanced-patches']);
                  return ['revanced-patches'];
                },
              );

              return '$answer (${repos.length} repo)';
            },
          );
        },
      );

      await waitForSend();

      // The conversation wrapper returns the body's result unchanged.
      expect(answer, 'All verified patches are safe. (1 repo)');
      expect(
        spans.keys,
        containsAll(<String>[
          'invoke_agent ReVance Assistant',
          'chat gpt-4o',
          'execute_tool list_repos',
        ]),
        reason: 'all three AI spans must reach the sender',
      );

      // Span hierarchy: model and tool calls nest under the agent run.
      expect(spans['chat gpt-4o']!['parent'], 'invoke_agent ReVance Assistant');
      expect(
        spans['execute_tool list_repos']!['parent'],
        'invoke_agent ReVance Assistant',
      );

      // Conversation grouping: one id across every AI span.
      for (final name in <String>[
        'invoke_agent ReVance Assistant',
        'chat gpt-4o',
        'execute_tool list_repos',
      ]) {
        expect(attr(name, 'gen_ai.conversation.id'), 'conv_test_abc123');
      }

      // AI request span per the manual instrumentation contract.
      expect(attr('chat gpt-4o', 'sentry.op'), 'gen_ai.chat');
      expect(attr('chat gpt-4o', 'gen_ai.operation.name'), 'chat');
      expect(attr('chat gpt-4o', 'gen_ai.provider.name'), 'openai');
      expect(attr('chat gpt-4o', 'gen_ai.request.model'), 'gpt-4o');
      expect(attr('chat gpt-4o', 'gen_ai.request.temperature'), 0.2);
      expect(
        attr('chat gpt-4o', 'gen_ai.system_instructions'),
        'You are a ReVance expert.',
      );
      expect(
        attr('chat gpt-4o', 'gen_ai.input.messages'),
        contains('"role":"user"'),
      );
      expect(
        attr('chat gpt-4o', 'gen_ai.output.messages'),
        contains('All verified patches are safe.'),
      );
      expect(attr('chat gpt-4o', 'gen_ai.response.model'), 'gpt-4o-2024-08-06');
      expect(attr('chat gpt-4o', 'gen_ai.usage.input_tokens'), 120);
      expect(attr('chat gpt-4o', 'gen_ai.usage.output_tokens'), 24);
      expect(attr('chat gpt-4o', 'gen_ai.usage.total_tokens'), 144);

      // Tool span.
      expect(
        attr('execute_tool list_repos', 'sentry.op'),
        'gen_ai.execute_tool',
      );
      expect(attr('execute_tool list_repos', 'gen_ai.tool.name'), 'list_repos');
      expect(
        attr('execute_tool list_repos', 'gen_ai.tool.call.arguments'),
        contains('revanced'),
      );
      expect(
        attr('execute_tool list_repos', 'gen_ai.tool.call.result'),
        contains('revanced-patches'),
      );

      // Agent span.
      expect(
        attr('invoke_agent ReVance Assistant', 'sentry.op'),
        'gen_ai.invoke_agent',
      );
      expect(
        attr('invoke_agent ReVance Assistant', 'gen_ai.agent.name'),
        'ReVance Assistant',
      );

      // The envelopes reached Sentry: at least one send, none rejected.
      expect(
        transport.sendCount,
        greaterThan(0),
        reason: 'no envelope left the app — check network/DSN',
      );
      expect(
        transport.failureCount,
        0,
        reason: 'Sentry rejected an envelope (HTTP error or rate limit)',
      );
      debugPrint(
        'Sentry ingest: ${transport.sendCount} envelope(s) accepted by '
        'o4510758181208064.ingest.de.sentry.io, ${transport.failureCount} rejected.',
      );
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test('failing tool call records an error span', () async {
    final sendsBefore = transport.sendCount;

    await expectLater(
      AgentTracing.tool(
        toolName: 'flaky_tool',
        run: (_) async => throw StateError('boom'),
      ),
      throwsA(isA<StateError>()),
    );

    await waitForSpan('execute_tool flaky_tool');

    final snapshot = spans['execute_tool flaky_tool'];
    expect(snapshot, isNotNull, reason: 'erroring span must still be sent');
    expect(snapshot!['status'], 'error');
    expect(
      (snapshot['attributes'] as Map<String, Object?>)['error.type'],
      'StateError',
    );

    // Wait for that erroring span's envelope to leave the app too.
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (
      transport.sendCount == sendsBefore && DateTime.now().isBefore(deadline)
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(
      transport.sendCount,
      greaterThan(sendsBefore),
      reason: 'the erroring span was never sent',
    );
    expect(transport.failureCount, 0);
  });

  test('a conversation started without an id gets an opaque one', () {
    final generated = AgentTracing.startConversation();
    expect(generated, matches(RegExp(r'^conv_[0-9a-f]{32}$')));
    AgentTracing.endConversation();
    expect(AgentTracing.conversationId, isNull);
  });
}
