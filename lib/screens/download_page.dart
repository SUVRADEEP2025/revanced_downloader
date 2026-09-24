import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:rd_manager/download_coordinator.dart';
import 'package:rd_manager/models/models.dart';
import 'package:rd_manager/screens/repo_data_list.dart';
import 'package:rd_manager/services/asset_status_service.dart';
import 'package:rd_manager/services/github_api.dart';
import 'package:rd_manager/widgets/widgets.dart';

class DownloadPage extends StatefulWidget {
  final String userName;
  final String repoName;
  final List<RepoData> repos;
  final int currentIndex;
  final Function(int) onRepoChanged;

  const DownloadPage({
    super.key,
    required this.userName,
    required this.repoName,
    required this.repos,
    required this.currentIndex,
    required this.onRepoChanged,
  });

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final Dio _dio = Dio();
  final GithubApi _api = GithubApi();
  final DownloadCoordinator _downloadCoordinator = DownloadCoordinator();

  bool _isLoading = true;
  List<GithubAsset> _assets = [];
  Map<String, AssetState> _statuses = {};
  String? _errorMessage;
  String _searchQuery = '';

  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _cancelToken = CancelToken();
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _fetchReleases();
  }

  @override
  void dispose() {
    _cancelToken?.cancel('Widget disposed');
    _downloadCoordinator.dispose();
    _dio.close();
    _api.close();
    super.dispose();
  }

  Future<void> _fetchReleases() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      _assets = await _api.fetchLatestAssets(
        widget.userName,
        widget.repoName,
        archFilter: true,
      );

      // Resolve downloaded/updatable statuses in parallel with icon fetch.
      final statusFuture = _refreshStatuses();
      if (!mounted) return;
      setState(() => _isLoading = false);

      // Proactively fetch metadata/icons for assets.
      await Future.wait([
        statusFuture,
        _api.fillMissingIcons(_assets),
      ]);
      if (mounted) setState(() {});
    } on DioException catch (e) {
      log(e.toString());
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout ||
                e.type == DioExceptionType.sendTimeout
            ? 'Connection timed out. Please check your internet.'
            : 'Failed to fetch releases: ${e.message}';
      });
    } catch (e) {
      log(e.toString());
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred.';
      });
    }
  }

  Future<void> _refreshStatuses() async {
    await AssetStatusService.instance.refresh();
    final statuses = await AssetStatusService.instance.resolveAll(_assets);
    if (!mounted) return;
    setState(() => _statuses = statuses);
  }

  List<GithubAsset> get _filteredAssets {
    if (_searchQuery.isEmpty) return _assets;
    final q = _searchQuery.toLowerCase();
    return _assets.where((a) => a.name.toLowerCase().contains(q)).toList();
  }

  void _showActionOptions(GithubAsset asset) {
    if (!mounted) return;
    showAssetActionSheet(context, asset: asset, onDownload: _processDownload);
  }

  Future<void> _processDownload(GithubAsset asset) async {
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
        ),                        onCompleted: () {
                          if (!mounted) return;
                          if (Navigator.canPop(context)) Navigator.pop(context);
                          _snack('Installation started');
                          // Mark the asset as downloaded right away.
                          AssetStatusService.instance.invalidateDownloads();
                          _refreshStatuses();
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
      _fetchReleases();
    });
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName}/${widget.repoName}'),
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
      drawer: widget.repos.length > 1
          ? RepoDrawer(
              repos: widget.repos,
              selectedIndex: widget.currentIndex,
              onSelectRepo: widget.onRepoChanged,
              onSelectAllApps: () => widget.onRepoChanged(-1),
              onManageRepos: _openManageRepos,
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _fetchReleases,
      child: _errorMessage != null || _assets.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: Center(
                      child: Text(_errorMessage ?? 'No assets found.'),
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
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _filteredAssets.length,
                    itemBuilder: (context, index) {
                      final asset = _filteredAssets[index];
                      final state = _statuses['${asset.id}'];
                      return AssetListItem(
                        asset: asset,
                        onTap: () => _showActionOptions(asset),
                        onLongPress: () =>
                            shareAssetLink(context, asset.downloadUrl),
                        status: switch (state) {
                          AssetState.downloaded => AssetStatus.downloaded,
                          AssetState.updatable => AssetStatus.updatable,
                          AssetState.upToDate => AssetStatus.upToDate,
                          _ => AssetStatus.none,
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
