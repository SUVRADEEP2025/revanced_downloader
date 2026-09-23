import 'dart:developer';

import 'package:flutter/material.dart';

import 'package:rd_manager/download_coordinator.dart';
import 'package:rd_manager/models/models.dart';
import 'package:rd_manager/screens/repo_data_list.dart';
import 'package:rd_manager/services/github_api.dart';
import 'package:rd_manager/widgets/widgets.dart';

/// A single entry in the aggregated All Apps list: an asset plus its repo.
class AllAppsEntry {
  final GithubAsset asset;
  final RepoData repo;

  const AllAppsEntry({required this.asset, required this.repo});
}

class AllAppsView extends StatefulWidget {
  final List<RepoData> repos;
  final Function(int) onRepoChanged;

  const AllAppsView({
    super.key,
    required this.repos,
    required this.onRepoChanged,
  });

  @override
  State<AllAppsView> createState() => _AllAppsViewState();
}

class _AllAppsViewState extends State<AllAppsView> {
  final GithubApi _api = GithubApi();
  final DownloadCoordinator _downloadCoordinator = DownloadCoordinator();

  bool _isLoading = true;
  List<AllAppsEntry> _entries = [];
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchAllReleases();
  }

  @override
  void dispose() {
    _downloadCoordinator.dispose();
    _api.close();
    super.dispose();
  }

  Future<void> _fetchAllReleases() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _entries = [];
      });

      final List<AllAppsEntry> entries = [];

      // Fetch from all repositories.
      for (final repo in widget.repos) {
        try {
          final assets = await _api.fetchLatestAssets(
            repo.userName,
            repo.repoName,
            archFilter: false,
          );
          for (final asset in assets) {
            entries.add(AllAppsEntry(asset: asset, repo: repo));
          }
        } catch (e) {
          log('Error fetching from ${repo.userName}/${repo.repoName}: $e');
        }
      }

      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isLoading = false;
        if (_entries.isEmpty) {
          _errorMessage =
              'No assets found. Please check your internet or repository list.';
        }
      });

      // Fetch metadata for All Apps.
      await _api.fillMissingIcons(entries.map((e) => e.asset).toList());
      if (mounted) setState(() {});
    } catch (e) {
      log(e.toString());
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred.';
      });
    }
  }

  List<AllAppsEntry> get _filteredEntries {
    if (_searchQuery.isEmpty) return _entries;
    final q = _searchQuery.toLowerCase();
    return _entries
        .where((entry) => entry.asset.name.toLowerCase().contains(q))
        .toList();
  }

  void _showActionOptions(AllAppsEntry entry) {
    if (!mounted) return;
    showAssetActionSheet(
      context,
      asset: entry.asset,
      repo: entry.repo,
      onDownload: (_) => _processDownload(entry),
    );
  }

  Future<void> _processDownload(AllAppsEntry entry) async {
    final asset = entry.asset;
    if (!mounted) return;

    // Show the dialog before starting the download so that any
    // synchronous error callbacks can safely dismiss it.
    final dialogFuture = showDownloadProgressDialog(
      context,
      coordinator: _downloadCoordinator,
      assetName: asset.name,
      onCancel: () {
        _downloadCoordinator.cancelDownload();
        _snack('Download cancelled');
      },
    );

    try {
      await _downloadCoordinator.startDownload(
        DownloadRequest(
          name: asset.name,
          url: asset.downloadUrl,
          digest: asset.digest,
        ),
        onCompleted: () {
          if (!mounted) return;
          if (Navigator.canPop(context)) Navigator.pop(context);
          _snack('Installation started');
        },
        onError: (message) {
          if (!mounted) return;
          if (Navigator.canPop(context)) Navigator.pop(context);
          _snack(message);
        },
      );
    } catch (e, st) {
      log('Failed to start download: $e', stackTrace: st);
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      _snack('Failed to start download');
    }

    // Ensure the dialog has completed (i.e. been popped) before finishing.
    await dialogFuture;
  }

  void _openManageRepos() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RepoDataList()),
    ).then((_) {
      // Refresh when returning from settings.
      _fetchAllReleases();
    });
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Apps'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'manage') _openManageRepos();
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'manage',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 12),
                    Text('Manage Repositories'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: RepoDrawer(
        repos: widget.repos,
        selectedIndex: -1,
        onSelectRepo: widget.onRepoChanged,
        onSelectAllApps: () {
          // Already on All Apps.
        },
        onManageRepos: _openManageRepos,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAllReleases,
        child: _errorMessage != null || _entries.isEmpty
            ? LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: constraints.maxHeight,
                      child: Center(
                        child: Text(
                          _errorMessage ??
                              'No apps found across all repositories.',
                        ),
                      ),
                    ),
                  );
                },
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: AppSearchBar(
                      hintText: 'Search assets...',
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _filteredEntries.length,
                      itemBuilder: (context, index) {
                        final entry = _filteredEntries[index];
                        return AssetListItem(
                          asset: entry.asset,
                          repo: entry.repo,
                          onTap: () => _showActionOptions(entry),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
