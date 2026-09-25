import 'package:flutter/material.dart';

import '../theme/tokens/app_radius.dart';
import '../theme/tokens/app_spacing.dart';

/// Small pill badges for free-form tags, reused by the list row, the detail
/// screen and the import review row so the three do not drift.
///
/// [maxVisible] caps how many pills draw before collapsing the rest into one
/// "+N" pill — the list row passes this to keep row heights predictable across
/// restaurants with wildly different tag counts; the detail and import screens
/// pass null (unbounded), since neither is a scrolling list of many same-shaped
/// rows. Ported from `ui/common/TagPills.kt`.
class TagPillRow extends StatelessWidget {
  const TagPillRow({super.key, required this.tags, this.maxVisible});

  final List<String> tags;
  final int? maxVisible;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }
    final int? limit = maxVisible;
    final List<String> visible = limit == null ? tags : tags.take(limit).toList();
    final int overflow = tags.length - visible.length;
    return Wrap(
      spacing: AppSpacing.xs + 2,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        for (final String tag in visible) TagPill(text: tag),
        if (overflow > 0) TagPill(text: '+$overflow'),
      ],
    );
  }
}

/// A single pill. Public so screens drawing one tag outside a row (the import
/// review's tag list, for instance) can reuse the exact shape.
class TagPill extends StatelessWidget {
  const TagPill({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: AppRadius.pill,
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: scheme.onSecondaryContainer),
      ),
    );
  }
}
