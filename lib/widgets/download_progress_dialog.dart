import 'package:flutter/material.dart';

import 'package:rd_manager/download_coordinator.dart';

/// Non-dismissible progress dialog bound to a [DownloadCoordinator]'s
/// progress/status notifiers, with a cancel button.
Future<void> showDownloadProgressDialog(
  BuildContext context, {
  required DownloadCoordinator coordinator,
  required String assetName,
  required VoidCallback onCancel,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          backgroundColor: Theme.of(dialogContext).colorScheme.surfaceContainer,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      dialogContext,
                    ).colorScheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.download_rounded,
                    size: 32,
                    color: Theme.of(
                      dialogContext,
                    ).colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Downloading',
                  style: Theme.of(dialogContext).textTheme.titleMedium
                      ?.copyWith(
                        color: Theme.of(
                          dialogContext,
                        ).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  assetName,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    dialogContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 32),
                ValueListenableBuilder<double>(
                  valueListenable: coordinator.progressNotifier,
                  builder: (context, value, _) {
                    return Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: value,
                            minHeight: 12,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${(value * 100).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<String>(
                  valueListenable: coordinator.statusNotifier,
                  builder: (context, value, _) {
                    if (value.endsWith('%')) return const SizedBox.shrink();
                    return Text(
                      value,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    );
                  },
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () {
                    onCancel();
                    Navigator.pop(dialogContext);
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel Download'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
