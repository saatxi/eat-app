import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_theme_mode.dart';
import 'tokens/app_radius.dart';
import 'tokens/app_spacing.dart';
import 'tokens/cuisine_accents.dart';

/// A development-only screen that renders every design token the theme
/// defines, with in-place palette and light/dark switchers.
///
/// This exists to make the token system visible and manually verifiable before
/// any real screen is built; it is replaced by the actual screens in a later
/// block and is not reachable from the app's navigation.
///
/// Its labels are the token identifiers themselves (colour-role names, text
/// style names), not user-facing copy, so they are intentionally not routed
/// through localization.
class ThemeGallery extends StatelessWidget {
  const ThemeGallery({
    super.key,
    required this.palette,
    required this.mode,
    required this.onPaletteChanged,
    required this.onModeChanged,
  });

  final AppPalette palette;
  final AppThemeMode mode;
  final ValueChanged<AppPalette> onPaletteChanged;
  final ValueChanged<AppThemeMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final CuisineAccents accents = CuisineAccents.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('EatApp'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Theme mode',
            icon: Icon(
              mode == AppThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
            ),
            onPressed: () => onModeChanged(
              mode == AppThemeMode.dark ? AppThemeMode.light : AppThemeMode.dark,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.screenGutter.add(
          const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        ),
        children: <Widget>[
          _Section(
            title: 'Palette',
            child: SegmentedButton<AppPalette>(
              showSelectedIcon: false,
              segments: <ButtonSegment<AppPalette>>[
                for (final AppPalette value in AppPalette.values)
                  ButtonSegment<AppPalette>(
                    value: value,
                    label: Text(value.tones.name),
                  ),
              ],
              selected: <AppPalette>{palette},
              onSelectionChanged: (Set<AppPalette> selection) =>
                  onPaletteChanged(selection.first),
            ),
          ),
          _Section(
            title: 'Colour roles',
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final (String, Color) role in <(String, Color)>[
                  ('primary', scheme.primary),
                  ('onPrimary', scheme.onPrimary),
                  ('primaryContainer', scheme.primaryContainer),
                  ('onPrimaryContainer', scheme.onPrimaryContainer),
                  ('secondary', scheme.secondary),
                  ('secondaryContainer', scheme.secondaryContainer),
                  ('tertiary', scheme.tertiary),
                  ('tertiaryContainer', scheme.tertiaryContainer),
                  ('error', scheme.error),
                  ('errorContainer', scheme.errorContainer),
                  ('surface', scheme.surface),
                  ('surfaceContainer', scheme.surfaceContainer),
                  ('surfaceContainerHighest', scheme.surfaceContainerHighest),
                  ('onSurfaceVariant', scheme.onSurfaceVariant),
                  ('outline', scheme.outline),
                ])
                  _Swatch(name: role.$1, color: role.$2),
              ],
            ),
          ),
          _Section(
            title: 'Cuisine accents',
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (int i = 0; i < accents.slots.length; i++)
                  _AccentChip(index: i, tint: accents[i]),
              ],
            ),
          ),
          _Section(
            title: 'Type scale',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final (String, TextStyle?) style in <(String, TextStyle?)>[
                  ('displayLarge', text.displayLarge),
                  ('displayMedium', text.displayMedium),
                  ('displaySmall', text.displaySmall),
                  ('headlineLarge', text.headlineLarge),
                  ('headlineMedium', text.headlineMedium),
                  ('headlineSmall', text.headlineSmall),
                  ('titleLarge', text.titleLarge),
                  ('titleMedium', text.titleMedium),
                  ('titleSmall', text.titleSmall),
                  ('bodyLarge', text.bodyLarge),
                  ('bodyMedium', text.bodyMedium),
                  ('bodySmall', text.bodySmall),
                  ('labelLarge', text.labelLarge),
                  ('labelMedium', text.labelMedium),
                  ('labelSmall', text.labelSmall),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        SizedBox(
                          width: 128,
                          child: Text(style.$1, style: text.labelSmall),
                        ),
                        Expanded(
                          child: Text(
                            'Restaurant',
                            style: style.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          _Section(
            title: 'Spacing',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final (String, double) step in <(String, double)>[
                  ('xxs', AppSpacing.xxs),
                  ('xs', AppSpacing.xs),
                  ('sm', AppSpacing.sm),
                  ('md', AppSpacing.md),
                  ('lg', AppSpacing.lg),
                  ('xl', AppSpacing.xl),
                  ('xxl', AppSpacing.xxl),
                  ('xxxl', AppSpacing.xxxl),
                ])
                  Row(
                    children: <Widget>[
                      SizedBox(
                        width: 48,
                        child: Text(step.$1, style: text.labelSmall),
                      ),
                      Container(
                        width: step.$2,
                        height: 12,
                        color: scheme.primary,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          _Section(
            title: 'Radius',
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: <Widget>[
                for (final (String, BorderRadius) step in <(String, BorderRadius)>[
                  ('extraSmall', AppRadius.extraSmallAll),
                  ('small', AppRadius.smallAll),
                  ('medium', AppRadius.mediumAll),
                  ('large', AppRadius.largeAll),
                  ('extraLarge', AppRadius.extraLargeAll),
                  ('pill', AppRadius.pill),
                ])
                  Container(
                    width: 72,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: step.$2,
                    ),
                    child: Text(
                      step.$1,
                      style: text.labelSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.sectionGap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 96,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppRadius.smallAll,
            border: Border.all(color: scheme.outlineVariant),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: 96,
          child: Text(
            name,
            style: Theme.of(context).textTheme.labelSmall,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

class _AccentChip extends StatelessWidget {
  const _AccentChip({required this.index, required this.tint});

  final int index;
  final CuisineTint tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: tint.container,
        borderRadius: AppRadius.pill,
      ),
      child: Text(
        '${index + 1}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: tint.onContainer,
            ),
      ),
    );
  }
}
