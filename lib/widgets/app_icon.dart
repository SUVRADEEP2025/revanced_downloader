import 'package:flutter/material.dart';

/// Rounded app icon with a graceful fallback glyph.
class AppIcon extends StatelessWidget {
  const AppIcon({
    super.key,
    this.url,
    this.size = 32,
    this.fallbackIcon = Icons.extension,
  });

  final String? url;
  final double size;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;

    if (url == null || url!.isEmpty) {
      return Icon(fallbackIcon, size: size, color: color);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) =>
            Icon(fallbackIcon, size: size, color: color),
      ),
    );
  }
}
