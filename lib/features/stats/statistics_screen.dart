import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_radius.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../core/widgets/animated_counter.dart';
import '../../core/widgets/cuisine_visuals.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/price_range_label.dart';
import '../../core/widgets/rating_trend_chart.dart';
import '../../data/models/stats_projections.dart';
import 'monthly_trends.dart';
import 'statistics_controller.dart';

/// The statistics screen: a headline total, three supporting counts, then the
/// cuisine, price, visits-per-month, rating-trend and top-tags breakdowns.
///
/// Ported from `ui/stats/StatisticsScreen.kt`. Both time-series are drawn from
/// the same hand-made widgets the detail screen's trend uses; the monthly bars
/// are plain flexed containers rather than a canvas, so the counts stay real
/// text a screen reader can read.
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  StatisticsController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= StatisticsController(
      repository: AppScope.of(context).restaurants,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final StatisticsController controller = _controller!;

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final StatisticsState state = controller.state;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.statsTitle)),
          body: switch (state) {
            StatisticsState(isInitialLoad: true) => const Center(
                child: CircularProgressIndicator(),
              ),
            StatisticsState(totalCount: 0) => EmptyState(
                icon: Icons.bar_chart_outlined,
                title: l10n.statsEmptyTitle,
                body: l10n.statsEmptyBody,
              ),
            _ => _Loaded(state: state),
          },
        );
      },
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.state});

  final StatisticsState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final List<MonthlyAverageRating> rated = <MonthlyAverageRating>[
      for (final MonthlyAverageRating point in state.monthlyRatingTrend)
        if (point.average != null) point,
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        // The total is promoted to its own headline tile rather than one of four
        // equal-weight tiles — it is the number that answers "how much have I
        // collected"; the other three just qualify it.
        _StatTile(
          count: state.totalCount,
          label: l10n.statsTileTotal,
          containerColor: theme.colorScheme.primaryContainer,
          contentColor: theme.colorScheme.onPrimaryContainer,
          valueStyle: theme.textTheme.displaySmall,
          padding: 20,
        ),
        const SizedBox(height: AppSpacing.sm),
        IntrinsicHeight(
          child: Row(
            spacing: AppSpacing.sm,
            children: <Widget>[
              Expanded(
                child: _StatTile(
                  count: state.visitedCount,
                  label: l10n.statsTileVisited,
                  containerColor: theme.colorScheme.surfaceContainerHighest,
                  contentColor: theme.colorScheme.onSurface,
                  valueStyle: theme.textTheme.headlineSmall,
                  padding: AppSpacing.md,
                ),
              ),
              Expanded(
                child: _StatTile(
                  count: state.wantToTryCount,
                  label: l10n.statsTileWantToTry,
                  containerColor: theme.colorScheme.surfaceContainerHighest,
                  contentColor: theme.colorScheme.onSurface,
                  valueStyle: theme.textTheme.headlineSmall,
                  padding: AppSpacing.md,
                ),
              ),
              Expanded(
                child: _StatTile(
                  value: state.averageRating == null
                      ? l10n.statsAverageRatingNone
                      : l10n.statsAverageRatingValue(state.averageRating!),
                  label: l10n.statsTileAverageRating,
                  containerColor: theme.colorScheme.surfaceContainerHighest,
                  contentColor: theme.colorScheme.onSurface,
                  valueStyle: theme.textTheme.headlineSmall,
                  padding: AppSpacing.md,
                ),
              ),
            ],
          ),
        ),
        if (state.cuisineCounts.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _StatsCard(
            title: l10n.statsSectionCuisines,
            children: <Widget>[
              for (final CuisineCount count in state.cuisineCounts)
                _BarRow(
                  leading: Icon(cuisineIcon(count.cuisineType), size: 18),
                  label: cuisineLabel(l10n, count.cuisineType),
                  count: count.count,
                  maxCount: state.cuisineCounts
                      .map((CuisineCount row) => row.count)
                      .reduce((int a, int b) => a > b ? a : b),
                ),
            ],
          ),
        ],
        if (state.priceRangeCounts.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _StatsCard(
            title: l10n.statsSectionPrice,
            children: <Widget>[
              for (final PriceRangeCount count
                  in (List<PriceRangeCount>.of(state.priceRangeCounts)
                    ..sort(
                      (PriceRangeCount a, PriceRangeCount b) =>
                          a.priceRange.compareTo(b.priceRange),
                    )))
                _BarRow(
                  label: count.priceRange == 0
                      ? l10n.statsPriceNotSet
                      : priceRangeLabel(l10n, count.priceRange),
                  count: count.count,
                  maxCount: state.priceRangeCounts
                      .map((PriceRangeCount row) => row.count)
                      .reduce((int a, int b) => a > b ? a : b),
                ),
            ],
          ),
        ],
        if (state.monthlyVisitCounts.any((MonthlyVisitCount m) => m.count > 0)) ...[
          const SizedBox(height: AppSpacing.lg),
          _StatsCard(
            title: l10n.statsSectionVisitsPerMonth,
            children: <Widget>[_MonthlyBars(counts: state.monthlyVisitCounts)],
          ),
        ],
        if (rated.length >= 2) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _StatsCard(
            title: l10n.statsSectionRatingTrend,
            children: <Widget>[
              SizedBox(
                height: 100,
                child: RatingTrendChart(
                  values: <double>[
                    for (final MonthlyAverageRating point in rated)
                      point.average!,
                  ],
                  lineColor: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
        if (state.tagCounts.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _StatsCard(
            title: l10n.statsSectionTopTags,
            children: <Widget>[
              for (final TagCount count in state.tagCounts)
                _BarRow(
                  label: count.name,
                  count: count.count,
                  maxCount: state.tagCounts
                      .map((TagCount row) => row.count)
                      .reduce((int a, int b) => a > b ? a : b),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    this.value,
    this.count,
    required this.label,
    required this.containerColor,
    required this.contentColor,
    required this.valueStyle,
    required this.padding,
  }) : assert(
          (value == null) != (count == null),
          'a tile shows either a formatted value or a countable one',
        );

  /// A pre-formatted value, for the tiles that are not a plain number — the
  /// average rating, which is a locale-formatted string, or an em dash.
  final String? value;

  /// A number the tile counts up to. Mutually exclusive with [value].
  final int? count;

  final String label;
  final Color containerColor;
  final Color contentColor;
  final TextStyle? valueStyle;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final int? count = this.count;
    final TextStyle? numberStyle = valueStyle?.copyWith(color: contentColor);
    return Card(
      margin: EdgeInsets.zero,
      color: containerColor,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (count != null)
              AnimatedCounter(value: count, style: numberStyle)
            else
              Text(
                value!,
                style: numberStyle?.copyWith(
                  // Tabular figures keep the digits from shifting width as the
                  // value changes.
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: contentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.count,
    required this.maxCount,
    this.leading,
  });

  final String label;
  final int count;
  final int maxCount;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[
            leading!,
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: Text(label)),
                    Text('$count', style: theme.textTheme.labelMedium),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: AppRadius.extraSmallAll,
                  child: LinearProgressIndicator(
                    value: maxCount == 0 ? 0 : count / maxCount,
                    minHeight: 6,
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

/// The trailing six months as six bottom-aligned bars, the tallest one filling
/// the card. The count rides above its bar so the chart is readable without
/// hovering, and the month initial sits underneath.
class _MonthlyBars extends StatelessWidget {
  const _MonthlyBars({required this.counts});

  final List<MonthlyVisitCount> counts;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final int maxCount = counts
        .map((MonthlyVisitCount row) => row.count)
        .fold(0, (int a, int b) => a > b ? a : b);

    return SizedBox(
      height: 130,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (final MonthlyVisitCount count in counts)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '${count.count}',
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Container(
                    // A month with no visits still shows a sliver, so the month
                    // is visibly present rather than missing.
                    height: maxCount == 0
                        ? 2
                        : 2 + (count.count / maxCount) * 70,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: count.count == 0
                          ? theme.colorScheme.outlineVariant
                          : theme.colorScheme.primary,
                      borderRadius: AppRadius.extraSmallAll,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _monthLabel(count.monthKey, locale),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _monthLabel(String monthKey, String locale) {
    final int year = int.parse(monthKey.substring(0, 4));
    final int month = int.parse(monthKey.substring(5));
    return DateFormat.MMM(locale).format(DateTime(year, month));
  }
}
