import 'package:flutter/material.dart';

/// One icon + text row, used by [OverviewCard] and the links card — optionally
/// tappable (an address that opens a map, a link that opens a browser).
class DetailInfoRow extends StatelessWidget {
  const DetailInfoRow({
    super.key,
    required this.icon,
    required this.text,
    this.onTap,
    this.textStyle,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: textStyle)),
        ],
      ),
    );
  }
}
