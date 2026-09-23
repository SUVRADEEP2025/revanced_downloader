/// Human-readable byte size, e.g. `12.34 MB`.
String formatBytes(int bytes) {
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}
