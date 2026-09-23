import 'package:flutter/material.dart';

/// A reusable search field with a built-in clear button.
///
/// Listens to its [TextEditingController], so every text change —
/// typing, autofill, or the clear button — flows through one path:
/// state update + [onChanged] callback. The clear button appears only
/// while the query is non-empty and resets the field, reporting an
/// empty string through [onChanged].
class AppSearchBar extends StatefulWidget {
  const AppSearchBar({
    super.key,
    required this.onChanged,
    this.hintText = 'Search...',
    this.controller,
  });

  final String? hintText;

  /// Called on every query change with the current text.
  final ValueChanged<String> onChanged;

  /// Optional externally-owned controller. If omitted, an internal
  /// controller is created and disposed with the widget.
  final TextEditingController? controller;

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;
  late final bool _ownsController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    _query = _controller.text;
    _controller.addListener(_handleTextChanged);
  }

  void _handleTextChanged() {
    final value = _controller.text;
    if (value == _query) return;
    setState(() => _query = value);
    widget.onChanged(value);
  }

  void _clear() => _controller.clear();

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _query.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Clear search',
                onPressed: _clear,
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
