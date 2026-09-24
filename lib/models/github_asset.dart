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

  String? get packageName {
    for (final part in name.split('_')) {
      if (part.contains('.') && part.split('.').length >= 3) {
        return part.replaceAll('.apk', '').replaceAll('.aab', '');
      }
    }
    return null;
  }
}
