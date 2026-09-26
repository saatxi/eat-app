import 'package:flutter/material.dart';

import '../theme/tokens/app_spacing.dart';

/// The centred illustration/title/body block shown when a screen has nothing to
/// draw, with an optional call to action. Reused by the list, favourites,
/// roulette and statistics screens. Ported from the Android app's list-screen
/// `EmptyState`, which the favourites screen also shared.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.actionEnabled = true,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Null draws no button at all.
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool actionEnabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Decorative: the title and body below say everything this conveys.
            ExcludeSemantics(child: _EmptyStateArt(icon: icon)),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(
              body,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.lg + AppSpacing.xs),
                child: FilledButton(
                  onPressed: actionEnabled ? onAction : null,
                  child: Text(actionLabel!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The art above an [EmptyState]'s text: a soft tinted disc carrying the icon,
/// with two accents offset off its edge.
///
/// The lone grey glyph this replaces read as "a control that failed to load";
/// a composed block reads as a deliberate part of the page, which is what an
/// empty state is. Everything is drawn from the palette, so it follows the
/// user's theme and brightness.
class _EmptyStateArt extends StatelessWidget {
  const _EmptyStateArt({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 136,
      height: 124,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
          ),
          Positioned(
            top: 0,
            right: 6,
            child: _AccentDot(size: 24, color: scheme.secondaryContainer),
          ),
          Positioned(
            bottom: 2,
            left: 2,
            child: _AccentDot(size: 15, color: scheme.tertiaryContainer),
          ),
          Icon(icon, size: 48, color: scheme.onPrimaryContainer),
        ],
      ),
    );
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
