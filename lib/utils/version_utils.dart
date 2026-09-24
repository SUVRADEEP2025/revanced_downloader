/// Utility helpers to extract and compare Android package versions from
/// release asset file names like `app-revanced_v5.4.0_arm64-v8a.apk`.
library;

/// Extracts the version token from an APK/AAB file name.
///
/// Heuristic (first match wins):
/// 1. `..._v1.2.3...` — an underscore-delimited token starting with `v`
///    followed by digits.
/// 2. `..._1.2.3...` — an underscore-delimited token made only of digits
///    and dots.
/// 3. `app-1.2.3...` — a hyphen-delimited token starting with `v` and digits.
///
/// Returns null when no plausible version token is found.
String? extractVersionFromName(String name) {
  // Strip the extension first so trailing tokens like `-arm64-v8a.apk`
  // don't confuse the hyphen-based pattern.
  final base = name.replaceAll(RegExp(r'\.(apk|aab)$', caseSensitive: false), '');

  // 1. ..._v1.2.3... (most ReVanced builds use this form)
  final vDash = RegExp(r'_v(\d+(?:\.\d+)+)').firstMatch(base);
  if (vDash != null) return vDash.group(1);

  // 2. ..._1.2.3...
  final plain = RegExp(r'_(\d+(?:\.\d+)+)').firstMatch(base);
  if (plain != null) return plain.group(1);

  // 3. ...-v1.2.3...
  final vToken = RegExp(r'-v(\d+(?:\.\d+)+)').firstMatch(base);
  if (vToken != null) return vToken.group(1);

  return null;
}

/// Parses a dotted version string into numeric parts.
///
/// Non-numeric segments are ignored; returns an empty list when nothing
/// numeric can be parsed (the caller should treat that as "unknown").
List<int> parseVersion(String version) {
  final parts = <int>[];
  for (final segment in version.split('.')) {
    final value = int.tryParse(segment.trim());
    if (value == null) continue;
    parts.add(value);
  }
  return parts;
}

/// Returns true when [candidate] is strictly newer than [installed].
///
/// Unknown versions (null / unparseable) never count as updates.
bool isNewerVersion(String? candidate, String? installed) {
  if (candidate == null || installed == null) return false;
  final candParts = parseVersion(candidate);
  final instParts = parseVersion(installed);
  if (candParts.isEmpty || instParts.isEmpty) return false;

  final length = candParts.length > instParts.length
      ? candParts.length
      : instParts.length;
  for (var i = 0; i < length; i++) {
    final c = i < candParts.length ? candParts[i] : 0;
    final p = i < instParts.length ? instParts[i] : 0;
    if (c != p) return c > p;
  }
  return false;
}
