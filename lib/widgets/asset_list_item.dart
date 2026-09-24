import 'package:flutter/material.dart';

import 'package:rd_manager/models/github_asset.dart';
import 'package:rd_manager/models/repo_data.dart';
import 'package:rd_manager/utils/format.dart';
import 'package:rd_manager/widgets/app_icon.dart';

/// Lifecycle status of an asset relative to the device and download history.
enum AssetStatus {
  /// No special information (default).
  none,

  /// This exact build is already downloaded (name matches history).
  downloaded,

  /// An older version of this app is installed; an update is available.
  updatable,

  /// The installed version matches the asset version.
  upToDate,
}

/// Card row for a downloadable asset. Shows provenance when [repo] is given
/// (aggregated All Apps view) and file size otherwise (per-repo view).
///
/// Cards are tinted by [status]:
/// - green  → downloaded already
/// - amber  → update available
/// - blue   → installed version matches
class AssetListItem extends StatelessWidget {
  const AssetListItem({
    super.key,
    required this.asset,
    this.repo,
    required this.onTap,
    this.onLongPress,
    this.status = AssetStatus.none,
  });

  final GithubAsset asset;
  final RepoData? repo;
  final VoidCallback onTap;

  /// Optional long-press action (e.g. share the download link).
  final VoidCallback? onLongPress;

  final AssetStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color tint, IconData statusIcon, String statusLabel) = switch (status) {
      AssetStatus.downloaded => (
        Colors.green,
        Icons.download_done_rounded,
        'Downloaded',
      ),
      AssetStatus.updatable => (
        Colors.amber,
        Icons.system_update_alt_rounded,
        'Update available',
      ),
      AssetStatus.upToDate => (
        scheme.primary,
        Icons.check_circle_outline_rounded,
        'Up to date',
      ),
      AssetStatus.none => (scheme.outlineVariant, Icons.circle, ''),
    };

    return Card(
      key: ValueKey(
        '${repo?.userName ?? ''}-${repo?.repoName ?? ''}-${asset.id}',
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: status == AssetStatus.none
            ? BorderSide.none
            : BorderSide(color: tint.withValues(alpha: 0.6), width: 1.2),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            leading: AppIcon(url: asset.imageLink),
            title: Text(
              asset.name,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  repo != null
                      ? '${repo!.userName}/${repo!.repoName}'
                      : formatBytes(asset.size),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (status != AssetStatus.none) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: tint),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: tint,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
