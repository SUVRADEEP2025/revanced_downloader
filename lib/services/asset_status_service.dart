import 'package:rd_manager/download_coordinator.dart'
    show DownloadHistoryStore;
import 'package:rd_manager/models/github_asset.dart';
import 'package:rd_manager/services/installed_apps_service.dart';
import 'package:rd_manager/utils/version_utils.dart';

/// Asset lifecycle status relative to the device (see [AssetStatus] in
/// asset_list_item.dart). Kept separate to avoid a widgets import here.
enum AssetState { none, downloaded, updatable, upToDate }

/// Resolves per-asset status by combining the local download history
/// (DownloadHistoryStore) with the device's installed packages.
class AssetStatusService {
  AssetStatusService._();

  static final AssetStatusService instance = AssetStatusService._();

  Map<String, String> _installedVersions = {};
  Set<String>? _downloadedNames;

  /// Refreshes the cached device package list. Call once before resolving
  /// statuses (e.g. after fetching releases).
  Future<void> refresh() async {
    _installedVersions = await InstalledAppsService.getInstalledVersions();
  }

  Future<Set<String>> _downloaded() async {
    final cached = _downloadedNames;
    if (cached != null) return cached;
    _downloadedNames =
        await DownloadHistoryStore.instance.getDownloadedNames();
    return _downloadedNames!;
  }

  /// Clears cached history (call after a new download completes).
  void invalidateDownloads() {
    _downloadedNames = null;
  }

  /// Resolves the status of a single asset.
  Future<AssetState> resolve(GithubAsset asset) async {
    // 1. Downloaded before? (exact asset file name match)
    final downloaded = await _downloaded();
    if (downloaded.contains(asset.name)) return AssetState.downloaded;

    // 2. Compare release version against the installed package version.
    final pkg = asset.packageName ?? packageNameFromAssetName(asset.name);
    final assetVersion = extractVersionFromName(asset.name);
    final installedVersion = pkg != null ? _installedVersions[pkg] : null;

    if (pkg != null &&
        installedVersion != null &&
        assetVersion != null &&
        isNewerVersion(assetVersion, installedVersion)) {
      return AssetState.updatable;
    }

    // 3. Installed and version matches → up to date.
    if (pkg != null &&
        _installedVersions.containsKey(pkg) &&
        assetVersion != null &&
        !isNewerVersion(assetVersion, installedVersion)) {
      return AssetState.upToDate;
    }

    return AssetState.none;
  }

  /// Resolves statuses for many assets.
  Future<Map<String, AssetState>> resolveAll(Iterable<GithubAsset> assets) async {
    final statuses = <String, AssetState>{};
    for (final asset in assets) {
      statuses['${asset.id}'] = await resolve(asset);
    }
    return statuses;
  }
}
