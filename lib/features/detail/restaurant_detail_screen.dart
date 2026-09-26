import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_scope.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_radius.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../core/theme/tokens/cuisine_accents.dart';
import '../../core/widgets/cuisine_visuals.dart';
import '../../core/widgets/delete_confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/price_range_label.dart';
import '../../core/widgets/rating_and_price_row.dart';
import '../../core/widgets/rating_trend_chart.dart';
import '../../core/widgets/restaurant_thumbnail.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../core/widgets/tag_pill_row.dart';
import '../import_export/share_service.dart';
import '../list/restaurant_ui_model.dart';
import 'detail_state.dart';
import 'restaurant_detail_controller.dart';

/// Everything about one restaurant: its overview, rating and price, links, a
/// small rating trend and the reverse-chronological visit timeline.
///
/// Ported from `ui/detail/RestaurantDetailScreen.kt`. On a phone it is pushed as
/// a route; on a tablet-width window the shell keeps it beside the list, which
/// is what [embedded] marks.
class RestaurantDetailScreen extends StatefulWidget {
  const RestaurantDetailScreen({
    super.key,
    required this.restaurantId,
    this.onEdit,
    this.onLogVisit,
    this.embedded = false,
    this.onClose,
  });

  final String restaurantId;

  /// Null leaves the action hidden — the case in a bare widget test.
  final ValueChanged<String>? onEdit;
  final ValueChanged<String>? onLogVisit;

  /// True when this screen is the detail half of the tablet two-pane layout
  /// rather than a pushed route. It changes nothing about the layout — the back
  /// button was never there, since the shell's root route can't be popped — only
  /// what "leave this screen" means for the two states that offer it.
  final bool embedded;

  /// Called instead of popping when [embedded] and there is nothing left to
  /// show (the restaurant was deleted, or never existed), so the shell can clear
  /// its selection rather than popping itself off the stack.
  final VoidCallback? onClose;

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  RestaurantDetailController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppScope scope = AppScope.of(context);
    _controller ??= RestaurantDetailController(
      repository: scope.restaurants,
      preferences: scope.preferences,
      restaurantId: widget.restaurantId,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _open(String url) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String failure = AppLocalizations.of(context).detailLinkFailed;
    try {
      final bool opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        messenger.showSnackBar(SnackBar(content: Text(failure)));
      }
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(failure)));
    }
  }

  /// Shares just this restaurant, carrying its real visit history (the export
  /// reads the visits back from the repository rather than from the on-screen
  /// summary), so nothing is lost the way the Android app's fabricated single
  /// visit used to be.
  Future<void> _share(RestaurantUiModel restaurant) {
    return exportAndShareRestaurants(
      context,
      repository: AppScope.of(context).restaurants,
      restaurantIds: <String>[restaurant.id],
      singleName: restaurant.name,
    );
  }

  Future<void> _delete() async {
    final bool confirmed = await showDeleteConfirmDialog(context);
    if (!confirmed || !mounted) {
      return;
    }
    HapticFeedback.heavyImpact();
    await _controller?.deleteRestaurant();
    if (!mounted) {
      return;
    }
    if (widget.embedded) {
      widget.onClose?.call();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final RestaurantDetailController controller = _controller!;

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final DetailState state = controller.state;
        final RestaurantUiModel? restaurant =
            state is DetailLoaded ? state.restaurant : null;
        return Scaffold(
          appBar: AppBar(
            title: Text(restaurant?.name ?? ''),
            actions: <Widget>[
              if (restaurant != null) ...<Widget>[
                IconButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    controller.toggleFavorite();
                  },
                  tooltip: restaurant.isFavorite
                      ? l10n.actionRemoveFavorite
                      : l10n.actionAddFavorite,
                  icon: Icon(
                    restaurant.isFavorite
                        ? Icons.favorite
                        : Icons.favorite_border,
                  ),
                ),
                IconButton(
                  onPressed: () => widget.onEdit?.call(restaurant.id),
                  tooltip: l10n.detailActionEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: () => _share(restaurant),
                  tooltip: l10n.detailActionShare,
                  icon: const Icon(Icons.share_outlined),
                ),
                IconButton(
                  onPressed: _delete,
                  tooltip: l10n.detailActionDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
          body: switch (state) {
            DetailLoading() => const _DetailSkeleton(),
            DetailNotFound() => EmptyState(
                icon: Icons.restaurant_menu,
                title: l10n.detailNotFoundTitle,
                body: l10n.detailNotFoundBody,
                actionLabel: l10n.actionGoBack,
                onAction: widget.embedded
                    ? widget.onClose
                    : () => Navigator.of(context).pop(),
              ),
            final DetailLoaded loaded => _LoadedContent(
                state: loaded,
                onOpen: _open,
                onLogVisit: widget.onLogVisit,
              ),
          },
        );
      },
    );
  }
}

class _LoadedContent extends StatelessWidget {
  const _LoadedContent({
    required this.state,
    required this.onOpen,
    this.onLogVisit,
  });

  final DetailLoaded state;
  final ValueChanged<String> onOpen;

  /// Null leaves the visits section's action hidden — the case in a bare widget
  /// test, the same as [RestaurantDetailScreen.onEdit].
  final ValueChanged<String>? onLogVisit;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final RestaurantUiModel restaurant = state.restaurant;
    final String priceLabel = priceRangeLabel(l10n, restaurant.priceRange);
    final String? address = restaurant.formattedAddress;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // The other end of the row's [restaurantHeroTag]: the photo when there
          // is one, and the same cuisine badge the row fell back to otherwise,
          // so the shared element always has a counterpart on both screens.
          Hero(
            tag: restaurantHeroTag(restaurant.id),
            child: restaurant.photoPath != null
                ? ClipRRect(
                    borderRadius: AppRadius.mediumAll,
                    child: Image.file(
                      File(restaurant.photoPath!),
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                      semanticLabel: l10n.detailPhotoDescription,
                      errorBuilder:
                          (BuildContext context, Object error, StackTrace? stack) =>
                              const SizedBox.shrink(),
                    ),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: RestaurantThumbnail(
                      cuisineKey: restaurant.cuisineKey,
                      size: 72,
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel(l10n.detailSectionOverview),
          _InfoRow(
            icon: cuisineIcon(restaurant.cuisineKey),
            text: cuisineLabel(l10n, restaurant.cuisineKey),
            textStyle: Theme.of(context).textTheme.titleMedium,
          ),
          if (!restaurant.visited)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _InfoRow(
                icon: Icons.schedule_outlined,
                text: l10n.visitStatusWantToTry,
              ),
            ),
          if (address != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _InfoRow(
                icon: Icons.location_on_outlined,
                text: address,
                onTap: () => onOpen('geo:0,0?q=${Uri.encodeComponent(address)}'),
              ),
            ),
          if (restaurant.tagsLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TagPillRow(tags: restaurant.tags),
            ),
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel(l10n.detailSectionRating),
          RatingAndPriceRow(
            rating: restaurant.rating,
            priceLabel: priceLabel,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            pricePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ratingContentDescription: l10n.restaurantRatingDescription(
              restaurant.rating,
            ),
            priceContentDescription: priceLabel.isEmpty
                ? null
                : l10n.restaurantPriceDescription(priceLabel),
            priceContainerColor: Theme.of(context).colorScheme.primaryContainer,
            priceContentColor: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          if (restaurant.hasLinks) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _LinksCard(restaurant: restaurant, onOpen: onOpen),
          ],
          if (state.ratingTrend.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _RatingTrendSection(
              points: state.ratingTrend,
              cuisineKey: restaurant.cuisineKey,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _VisitsSection(
            visits: state.visits,
            cuisineKey: restaurant.cuisineKey,
            // Bound to this restaurant here: the section only has to know
            // whether the action exists at all.
            onAddVisit: onLogVisit == null
                ? null
                : () => onLogVisit!(restaurant.id),
          ),
        ],
      ),
    );
  }
}

/// A quiet label above a block, marked as a heading so TalkBack's "next
/// heading" gesture can hop between the screen's sections.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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

class _LinksCard extends StatelessWidget {
  const _LinksCard({required this.restaurant, required this.onOpen});

  final RestaurantUiModel restaurant;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? website = restaurant.website;
    final String? instagram = restaurant.instagram;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.detailSectionLinks,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (website != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _InfoRow(
                  icon: Icons.language,
                  text: website,
                  onTap: () => onOpen(website),
                ),
              ),
            if (instagram != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _InfoRow(
                  icon: Icons.alternate_email,
                  text: l10n.detailLinkHandleFormat(instagram),
                  onTap: () => onOpen('https://instagram.com/$instagram'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RatingTrendSection extends StatelessWidget {
  const _RatingTrendSection({required this.points, required this.cuisineKey});

  final List<RatingPoint> points;
  final String cuisineKey;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CuisineTint tint = cuisineTint(context, cuisineKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionLabel(l10n.detailSectionRatingTrend),
        Container(
          height: 100,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: tint.container,
            borderRadius: AppRadius.mediumAll,
          ),
          child: RatingTrendChart(
            values: <double>[for (final RatingPoint p in points) p.rating.toDouble()],
            lineColor: tint.onContainer,
          ),
        ),
      ],
    );
  }
}

class _VisitsSection extends StatelessWidget {
  const _VisitsSection({
    required this.visits,
    required this.cuisineKey,
    this.onAddVisit,
  });

  final List<VisitUiModel> visits;
  final String cuisineKey;

  /// Null leaves the action out of the header.
  final VoidCallback? onAddVisit;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // The action lives in its own section's header rather than in a FAB:
        // a FAB floats over a scrolling list and hides the very cards it is
        // about, which these are.
        Row(
          children: <Widget>[
            _SectionLabel(l10n.detailSectionVisits),
            const Spacer(),
            if (onAddVisit != null)
              TextButton.icon(
                onPressed: onAddVisit,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.detailActionLogVisit),
              ),
          ],
        ),
        if (visits.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Column(
              children: <Widget>[
                Icon(
                  Icons.schedule_outlined,
                  size: 40,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.detailVisitsEmptyTitle,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.detailVisitsEmptyBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: <Widget>[
              for (final VisitUiModel visit in visits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _VisitCard(visit: visit, cuisineKey: cuisineKey),
                ),
            ],
          ),
      ],
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.visit, required this.cuisineKey});

  final VisitUiModel visit;
  final String cuisineKey;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final CuisineTint tint = cuisineTint(context, cuisineKey);
    final String date = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(DateTime.fromMillisecondsSinceEpoch(visit.visitDate));
    final String? notes = visit.notes;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: tint.container,
        borderRadius: AppRadius.mediumAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                date,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: tint.onContainer,
                ),
              ),
              RatingAndPriceRow(
                rating: visit.rating,
                priceLabel: priceRangeLabel(l10n, visit.priceRange),
                showRatingLabel: false,
                starSize: 16,
              ),
            ],
          ),
          if (notes != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                notes,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tint.onContainer,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          if (visit.photoPaths.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: visit.photoPaths.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int index) => ClipRRect(
                    borderRadius: AppRadius.smallAll,
                    child: Image.file(
                      File(visit.photoPaths[index]),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      semanticLabel: l10n.visitCardPhotoDescription,
                      errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The same borderless two-block shape as the loaded screen, pulsing while the
/// restaurant is still being fetched.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const <Widget>[
          ShimmerBox(width: 120, height: 20),
          SizedBox(height: AppSpacing.md),
          ShimmerBox(width: 240, height: 16),
          SizedBox(height: 10),
          ShimmerBox(width: 180, height: 16),
          SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              ShimmerBox(width: 110, height: 18),
              ShimmerBox(width: 36, height: 20),
            ],
          ),
        ],
      ),
    );
  }
}
