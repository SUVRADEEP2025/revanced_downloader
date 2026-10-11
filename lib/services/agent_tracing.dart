import 'dart:convert';

import 'package:sentry_flutter/sentry_flutter.dart';

/// Manual Agent Tracing instrumentation for the app.
///
/// The Sentry Dart/Flutter SDK ships no automatic AI instrumentation, so LLM
/// calls, tool executions and agent runs are recorded by hand as spans that
/// follow the GenAI semantic conventions (`gen_ai.*` attributes), exactly as
/// the [manual instrumentation guide](https://docs.sentry.io/platforms/javascript/guides/node/agent-tracing/manual-instrumentation/)
/// prescribes for stacks without an integration.
///
/// Spans are created through [Sentry.startSpan] — the streaming span API the
/// SDK defaults to (`traceLifecycle = stream`) and the one Sentry's
/// [Conversations](https://docs.sentry.io/product/agents/conversations/) view
/// reads from.
///
/// Conversation grouping works by stamping `gen_ai.conversation.id` onto
/// every AI span created while a conversation is active; Sentry groups spans
/// sharing that id into one transcript, independent of trace boundaries.
///
/// ```dart
/// final reply = await AgentTracing.conversation(
///   id: sessionId,
///   userId: user.id,
///   body: () => AgentTracing.agent(
///     agentName: 'Support Agent',
///     run: (agent) => AgentTracing.chat(
///       provider: 'openai',
///       model: 'gpt-4o',
///       inputMessages: [
///         {'role': 'user', 'parts': [
///           {'type': 'text', 'content': question},
///         ]},
///       ],
///       run: (chat) async {
///         final result = await client.chat(...);
///         chat.setResponse(
///           text: result.text,
///           model: result.model,
///           inputTokens: result.usage.inputTokens,
///           outputTokens: result.usage.outputTokens,
///         );
///         return result.text;
///       },
///     ),
///   ),
/// );
/// ```
class AgentTracing {
  AgentTracing._();

  static String? _conversationId;

  /// Whether prompts, responses and tool payloads are attached to spans.
  ///
  /// Enabled by default: the Agent Tracing transcript and debugging workflow
  /// are built around seeing inputs, outputs and tool arguments/results.
  /// Turn it off (or drop individual attributes via `extraAttributes`) when
  /// that data must not leave the device.
  static bool captureContent = true;

  /// The conversation AI spans created from now on belong to, or `null`
  /// when no conversation is active.
  static String? get conversationId => _conversationId;

  /// Starts a conversation and returns its id.
  ///
  /// Pass the app's existing chat/session id when there is one, otherwise an
  /// opaque `conv_<hex>` id is generated. Reuse the same id across turns —
  /// even across traces — so the whole chat groups into one conversation.
  static String startConversation({String? id}) {
    return _conversationId = id ?? _newConversationId();
  }

  /// Stops attributing new spans to the current conversation.
  static void endConversation() {
    _conversationId = null;
  }

  /// Runs [body] inside a conversation, restoring the previous conversation
  /// afterwards. Optionally identifies the user for the Conversations list.
  static Future<T> conversation<T>({
    String? id,
    String? userId,
    String? email,
    String? username,
    required Future<T> Function() body,
  }) async {
    final previous = _conversationId;
    _conversationId = id ?? _newConversationId();
    if (userId != null || email != null || username != null) {
      setUser(id: userId, email: email, username: username);
    }
    try {
      return await body();
    } finally {
      _conversationId = previous;
    }
  }

  /// Attributes subsequent events and spans to a user. The Conversations view
  /// shows the first value it finds, in this order: [email], [username],
  /// ip address, then [id].
  static void setUser({String? id, String? email, String? username}) {
    assert(id != null || email != null || username != null);
    Sentry.configureScope(
      (scope) => scope.setUser(SentryUser(id: id, email: email, username: username)),
    );
  }

  /// Removes the user from the scope.
  static void clearUser() {
    Sentry.configureScope((scope) => scope.setUser(null));
  }

  /// Records a complete agent run (`gen_ai.invoke_agent`).
  ///
  /// Nest [chat] and [tool] calls inside [run]; they become child spans of
  /// this one automatically.
  static Future<T> agent<T>({
    required String agentName,
    String? pipelineName,
    Map<String, Object?> extraAttributes = const {},
    required Future<T> Function(GenAiSpan span) run,
  }) {
    return _trace<T>(
      spanName: 'invoke_agent $agentName',
      operation: 'invoke_agent',
      attributes: {
        'gen_ai.agent.name': agentName,
        'gen_ai.pipeline.name': pipelineName,
        ...extraAttributes,
      },
      run: run,
    );
  }

  /// Records one model request (`gen_ai.chat`).
  ///
  /// [inputMessages] should use the OTEL message shape
  /// (`{'role': 'user', 'parts': [{'type': 'text', 'content': '...'}]}`) so
  /// conversation titles and transcripts can be derived from them.
  /// Keep system prompts in [systemInstructions], not in [inputMessages].
  static Future<T> chat<T>({
    required String provider,
    required String model,
    List<Map<String, Object?>>? inputMessages,
    String? systemInstructions,
    String? agentName,
    String? pipelineName,
    double? temperature,
    double? topP,
    int? topK,
    int? maxTokens,
    Map<String, Object?> extraAttributes = const {},
    required Future<T> Function(GenAiSpan span) run,
  }) {
    return _trace<T>(
      spanName: 'chat $model',
      operation: 'chat',
      attributes: {
        'gen_ai.provider.name': provider,
        'gen_ai.request.model': model,
        'gen_ai.agent.name': agentName,
        'gen_ai.pipeline.name': pipelineName,
        'gen_ai.request.temperature': temperature,
        'gen_ai.request.top_p': topP,
        'gen_ai.request.top_k': topK,
        'gen_ai.request.max_tokens': maxTokens,
        if (captureContent && systemInstructions != null)
          'gen_ai.system_instructions': systemInstructions,
        if (captureContent && inputMessages != null)
          'gen_ai.input.messages': jsonEncode(inputMessages),
        ...extraAttributes,
      },
      run: run,
    );
  }

  /// Records one tool execution (`gen_ai.execute_tool`).
  static Future<T> tool<T>({
    required String toolName,
    Map<String, Object?>? arguments,
    String? description,
    String? agentName,
    Map<String, Object?> extraAttributes = const {},
    required Future<T> Function(GenAiSpan span) run,
  }) {
    return _trace<T>(
      spanName: 'execute_tool $toolName',
      operation: 'execute_tool',
      attributes: {
        'gen_ai.tool.name': toolName,
        'gen_ai.tool.description': description,
        'gen_ai.agent.name': agentName,
        if (captureContent && arguments != null)
          'gen_ai.tool.call.arguments': jsonEncode(arguments),
        ...extraAttributes,
      },
      run: run,
    );
  }

  /// Creates the span, runs [run] inside it and maps failures onto the span.
  static Future<T> _trace<T>({
    required String spanName,
    required String operation,
    required Map<String, Object?> attributes,
    required Future<T> Function(GenAiSpan span) run,
  }) {
    final spanAttributes = <String, SentryAttribute>{
      // Sentry reads the span op from this attribute in the streaming
      // lifecycle: `gen_ai.<gen_ai.operation.name>`.
      'sentry.op': SentryAttribute.string('gen_ai.$operation'),
      'gen_ai.operation.name': SentryAttribute.string(operation),
      if (_conversationId != null)
        'gen_ai.conversation.id': SentryAttribute.string(_conversationId!),
      for (final entry in attributes.entries)
        if (entry.value != null) entry.key: _attribute(entry.value!),
    };

    return Sentry.startSpan<T>(
      spanName,
      (span) async {
        final genAiSpan = GenAiSpan._(span);
        try {
          return await run(genAiSpan);
        } catch (error) {
          genAiSpan.markFailed(error);
          rethrow;
        }
      },
      attributes: spanAttributes,
    );
  }

  static String _newConversationId() => 'conv_${SentryId.newId()}';

  static SentryAttribute _attribute(Object value) {
    if (value is String) return SentryAttribute.string(value);
    if (value is bool) return SentryAttribute.bool(value);
    if (value is int) return SentryAttribute.int(value);
    if (value is double) return SentryAttribute.double(value);
    if (value is List<String>) return SentryAttribute.stringArray(value);
    if (value is List<int>) return SentryAttribute.intArray(value);
    if (value is List<double>) return SentryAttribute.doubleArray(value);
    if (value is List<bool>) return SentryAttribute.boolArray(value);
    // Span attributes only accept primitives; everything else rides along as
    // a JSON string, as the GenAI conventions require.
    try {
      return SentryAttribute.string(jsonEncode(value));
    } on Object {
      return SentryAttribute.string(value.toString());
    }
  }
}

/// Handle to the AI span currently being recorded.
class GenAiSpan {
  GenAiSpan._(this.span);

  /// The underlying streaming span, exposed for advanced use.
  final SentrySpanV2 span;

  /// Sets a raw `gen_ai.*` attribute. A `null` [value] removes it.
  void setAttribute(String key, Object? value) {
    if (value == null) {
      span.removeAttribute(key);
    } else {
      span.setAttribute(key, AgentTracing._attribute(value));
    }
  }

  /// Records token usage. [inputTokens] must be the total input count,
  /// including cache-read and cache-creation tokens, and [outputTokens] must
  /// include reasoning tokens — the cache/reasoning values are subsets of
  /// those totals and must not be added to them again. Sentry derives model
  /// cost from these numbers.
  void setUsage({
    required int inputTokens,
    required int outputTokens,
    int? cacheReadInputTokens,
    int? cacheCreationInputTokens,
    int? reasoningOutputTokens,
  }) {
    setAttribute('gen_ai.usage.input_tokens', inputTokens);
    setAttribute('gen_ai.usage.output_tokens', outputTokens);
    setAttribute('gen_ai.usage.total_tokens', inputTokens + outputTokens);
    if (cacheReadInputTokens != null) {
      setAttribute('gen_ai.usage.cache_read.input_tokens', cacheReadInputTokens);
    }
    if (cacheCreationInputTokens != null) {
      setAttribute(
        'gen_ai.usage.cache_creation.input_tokens',
        cacheCreationInputTokens,
      );
    }
    if (reasoningOutputTokens != null) {
      setAttribute(
        'gen_ai.usage.reasoning.output_tokens',
        reasoningOutputTokens,
      );
    }
  }

  /// Records what the model returned.
  ///
  /// Either pass [messages] (full message list) or [text] (assistant reply,
  /// wrapped in the OTEL message shape) — the latter is what conversation
  /// transcripts are rendered from.
  void setResponse({
    String? text,
    List<Map<String, Object?>>? messages,
    String? model,
    String? responseId,
    List<String>? finishReasons,
    bool? streaming,
  }) {
    if (messages != null) {
      setAttribute('gen_ai.output.messages', jsonEncode(messages));
    } else if (text != null && AgentTracing.captureContent) {
      setAttribute(
        'gen_ai.output.messages',
        jsonEncode([
          {
            'role': 'assistant',
            'parts': [
              {'type': 'text', 'content': text},
            ],
          },
        ]),
      );
    }
    if (model != null) setAttribute('gen_ai.response.model', model);
    if (responseId != null) setAttribute('gen_ai.response.id', responseId);
    if (finishReasons != null) {
      setAttribute('gen_ai.response.finish_reasons', finishReasons);
    }
    if (streaming != null) {
      setAttribute('gen_ai.response.streaming', streaming);
    }
  }

  /// Records the payload a tool returned.
  void setToolResult(Object? result) {
    if (!AgentTracing.captureContent) return;
    setAttribute('gen_ai.tool.call.result', result);
  }

  /// Marks the span as failed. Called automatically when the traced callback
  /// throws; call it manually when a failure is handled instead of thrown.
  void markFailed(Object error) {
    setAttribute('error.type', error.runtimeType.toString());
    span.status = SentrySpanStatusV2.error;
  }
}
