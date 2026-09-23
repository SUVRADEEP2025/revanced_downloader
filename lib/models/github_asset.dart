/// A single downloadable asset attached to a GitHub release.
class GithubAsset {
  final int id;
  String? imageLink;
  final String name;
  final String downloadUrl;
  final int size;
  final String digest;

  GithubAsset({
    required this.id,
    required this.name,
    this.imageLink,
    required this.downloadUrl,
    required this.size,
    required this.digest,
  });

  factory GithubAsset.fromJson(Map<String, dynamic> json) {
    return GithubAsset(
      id: json['id'],
      name: json['name'],
      imageLink: json['image_link'],
      downloadUrl: json['browser_download_url'],
      size: json['size'],
      digest: json['digest'] ?? '',
    );
  }

  /// Heuristic: the APK/AAB file name usually embeds the package name as a
  /// dotted segment (e.g. `com.example.app_v1.2.3_arm64.apk`).
  String? get packageName {
    for (final part in name.split('_')) {
      if (part.contains('.') && part.split('.').length >= 3) {
        return part.replaceAll('.apk', '').replaceAll('.aab', '');
      }
    }
    return null;
  }
}
