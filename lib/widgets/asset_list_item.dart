import 'package:flutter/material.dart';

import 'package:rd_manager/models/github_asset.dart';
import 'package:rd_manager/models/repo_data.dart';
import 'package:rd_manager/utils/format.dart';
import 'package:rd_manager/widgets/app_icon.dart';

/// Card row for a downloadable asset. Shows provenance when [repo] is given
/// (aggregated All Apps view) and file size otherwise (per-repo view).
class AssetListItem extends StatelessWidget {
  const AssetListItem({
    super.key,
    required this.asset,
    this.repo,
    required this.onTap,
  });

  final GithubAsset asset;
  final RepoData? repo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey(
        '${repo?.userName ?? ''}-${repo?.repoName ?? ''}-${asset.id}',
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
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
            subtitle: Text(
              repo != null
                  ? '${repo!.userName}/${repo!.repoName}'
                  : formatBytes(asset.size),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
