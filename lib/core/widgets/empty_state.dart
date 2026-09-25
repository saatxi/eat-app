import 'package:flutter/material.dart';

import '../theme/tokens/app_spacing.dart';

/// The centred icon/title/body block shown when a screen has nothing to draw,
/// with an optional call to action. Reused by the list, favourites, roulette
/// and statistics screens. Ported from the Android app's list-screen
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
            Icon(icon, size: 64, color: theme.colorScheme.onSurfaceVariant),
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
