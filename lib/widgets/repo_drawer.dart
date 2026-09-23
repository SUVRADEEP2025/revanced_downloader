import 'package:flutter/material.dart';

import 'package:rd_manager/models/repo_data.dart';

/// Navigation drawer listing repositories, the aggregated All Apps entry,
/// and repository management.
class RepoDrawer extends StatelessWidget {
  const RepoDrawer({
    super.key,
    required this.repos,
    required this.selectedIndex,
    required this.onSelectRepo,
    required this.onSelectAllApps,
    required this.onManageRepos,
  });

  final List<RepoData> repos;

  /// -1 selects the All Apps entry; otherwise a repo index.
  final int selectedIndex;

  final void Function(int index) onSelectRepo;
  final VoidCallback onSelectAllApps;
  final VoidCallback onManageRepos;

  @override
  Widget build(BuildContext context) {
    final isAllApps = selectedIndex == -1;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: const Text(
              'Repositories',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...List.generate(repos.length, (index) {
            final repo = repos[index];
            final selected = !isAllApps && selectedIndex == index;
            return ListTile(
              leading: Icon(
                Icons.code,
                color: selected ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(
                repo.repoName,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              subtitle: Text(
                repo.userName,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              selected: selected,
              onTap: () {
                Navigator.pop(context);
                onSelectRepo(index);
              },
            );
          }),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.view_list,
              color: isAllApps ? Theme.of(context).colorScheme.primary : null,
            ),
            title: const Text('All Apps'),
            selected: isAllApps,
            onTap: () {
              Navigator.pop(context);
              onSelectAllApps();
            },
          ),
          ListTile(
            leading: const Icon(Icons.library_add),
            title: const Text('Manage Repositories'),
            onTap: () {
              Navigator.pop(context);
              onManageRepos();
            },
          ),
        ],
      ),
    );
  }
}
