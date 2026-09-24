/// Client for the GitHub Releases API plus the icon-metadata side-channel.
library;

import 'dart:developer';

import 'package:dio/dio.dart';

import 'package:rd_manager/models/github_asset.dart';

/// App-metadata (icon, version info) for a package name.
class AppMeta {
  final String name;
  final String packageName;
  final String icon;
  final String versionName;
  final int versionCode;

  AppMeta({
    required this.name,
    required this.packageName,
    required this.icon,
    required this.versionName,
    required this.versionCode,
  });

  factory AppMeta.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? (json['nodes']?[0]?['data'] ?? {});
    final file = data['file'] ?? {};

    return AppMeta(
      name: data['name'] ?? '',
      packageName: data['package'] ?? '',
      icon: data['icon'] ?? '',
      versionName: file['vername'] ?? '',
      versionCode: file['vercode'] ?? 0,
    );
  }

  @override
  String toString() {
    return 'AppMeta(name: $name, package: $packageName, version: $versionName ($versionCode))';
  }
}

/// Client for the GitHub Releases API plus the icon-metadata side-channel.
class GithubApi {
  GithubApi({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

  final Dio _dio;

  /// Shared Dio for metadata lookups (replaces per-call instantiation).
  static final Dio _metaDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  static const String _host = 'https://api.github.com';

  /// Returns installable assets (apk/aab) of the latest release of a repo.
  ///
  /// When [archFilter] is true only ARM/universal variants are kept
  /// (per-repo view); the aggregated view keeps every apk/aab instead.
  Future<List<GithubAsset>> fetchLatestAssets(
    String userName,
    String repoName, {
    bool archFilter = true,
  }) async {
    final response = await _dio.get(
      '$_host/repos/$userName/$repoName/releases/latest',
    );
    final List<dynamic> assetsJson =
        (response.data as Map<String, dynamic>)['assets'] ?? [];
    return assetsJson
        .map((e) => GithubAsset.fromJson(e as Map<String, dynamic>))
        .where((asset) {
          final name = asset.name.toLowerCase();
          final installable = name.endsWith('.apk') || name.endsWith('.aab');
          if (!installable) return false;
          if (!archFilter) return true;
          return name.contains('arm64') ||
              name.contains('universal') ||
              name.contains('v8a');
        })
        .toList();
  }

  /// Best-effort icon lookup: derives the package name from the file name
  /// and queries the app-metadata service. Returns null when unknown.
  Future<String?> fetchIconFor(GithubAsset asset) async {
    final pkg = asset.packageName;
    if (pkg == null) return null;
    return fetchAppIcon(pkg);
  }

  /// Fills in [GithubAsset.imageLink] for every asset that has none,
  /// querying the metadata service in bounded parallel batches.
  Future<void> fillMissingIcons(
    List<GithubAsset> assets, {
    int concurrency = 4,
  }) async {
    final pending = assets.where((a) => a.imageLink == null).toList();
    if (pending.isEmpty) return;

    var index = 0;
    Future<void> worker() async {
      while (index < pending.length) {
        final asset = pending[index++];
        try {
          final icon = await fetchIconFor(asset);
          if (icon != null) asset.imageLink = icon;
        } catch (e) {
          log('Icon lookup failed for ${asset.name}: $e');
        }
      }
    }

    await Future.wait([
      for (var i = 0; i < concurrency && i < pending.length; i++) worker(),
    ]);
  }

  void close() => _dio.close();
}

/// Best-effort icon lookup against the app-metadata service.
Future<String?> fetchAppIcon(String packageName) async {
  try {
    final response = await _metaDioGet(
      'https://ws2-cache.aptoide.com/api/7/app/getMeta',
      queryParameters: {
        'cdn': 'web',
        'q': 'bXlDUFU9YXJtNjQtdjhhLGFybWVhYmktdjdhLGFybWVhYmkmbGVhbmJhY2s9MA',
        'country': 'IN',
        'limit': '1',
        'package_name': packageName,
        'sort': 'relevance',
        'view': 'response',
      },
    );

    if (response.data != null && response.statusCode == 200) {
      return AppMeta.fromJson(response.data).icon;
    }
    return null;
  } catch (e) {
    log(e.toString());
    return null;
  }
}

/// Thin wrapper so the shared static [_metaDio] stays testable/mutable.
Future<Response<dynamic>> _metaDioGet(
  String path, {
  required Map<String, dynamic> queryParameters,
}) {
  return GithubApi._metaDio.get(path, queryParameters: queryParameters);
}
