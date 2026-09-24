import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:rd_manager/models/github_asset.dart';
import 'package:rd_manager/models/repo_data.dart';
import 'package:rd_manager/services/share_service.dart';

Future<void> showAssetActionSheet(
  BuildContext context, {
  required GithubAsset asset,
  RepoData? repo,
  required Future<void> Function(GithubAsset asset) onDownload,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Action for ${asset.name}',
                style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Text(
                repo != null
                    ? 'From: ${repo.userName}/${repo.repoName}'
                    : 'Choose how you want to handle this file.',
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildButton(
                    sheetContext,
                    icon: Icons.system_update,
                    label: 'Download & Install',
                    color: Theme.of(sheetContext).colorScheme.primary,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onDownload(asset);
                    },
                  ),
                  _buildButton(
                    sheetContext,
                    icon: Icons.ios_share,
                    label: 'Share Link',
                    color: Theme.of(sheetContext).colorScheme.secondary,
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await shareAssetLink(sheetContext, asset.downloadUrl);
                    },
                  ),
                  _buildButton(
                    sheetContext,
                    icon: Icons.open_in_browser,
                    label: 'Open in Browser',
                    color: Theme.of(sheetContext).colorScheme.tertiary,
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _openInBrowser(sheetContext, asset.downloadUrl);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Shares [url] via the Android share sheet, surfacing errors as a snackbar.
Future<void> shareAssetLink(BuildContext context, String url) async {
  try {
    await ShareService.shareUrl(url);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing link: $e')),
      );
    }
  }
}

Future<void> _openInBrowser(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening link: $e')));
    }
  }
}

Widget _buildButton(
  BuildContext context, {
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );
}
