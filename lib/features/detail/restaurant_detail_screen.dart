import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_scope.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_radius.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../core/widgets/delete_confirm_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/photo_decode_size.dart';
import '../../core/widgets/price_range_label.dart';
import '../import_export/share_service.dart';
import '../list/restaurant_ui_model.dart';
import 'detail_state.dart';
import 'restaurant_detail_controller.dart';
import 'widgets/detail_header.dart';
import 'widgets/detail_skeleton.dart';
import 'widgets/links_card.dart';
import 'widgets/overview_card.dart';
import 'widgets/rating_trend_section.dart';
import 'widgets/visits_section.dart';

/// Everything about one restaurant: its overview, rating and price, links, a
/// small rating trend and the reverse-chronological visit timeline.
///
/// Ported from `ui/detail/RestaurantDetailScreen.kt`. On a phone it is pushed as
/// a route; on a tablet-width window the shell keeps it beside the list, which
/// is what [embedded] marks. The screen's sections each moved to their own file
/// under `widgets/` once this grew past 800 lines.
class RestaurantDetailScreen extends StatefulWidget {
  const RestaurantDetailScreen({
    super.key,
    required this.restaurantId,
    this.onEdit,
    this.onLogVisit,
    this.onEditVisit,
    this.embedded = false,
    this.onClose,
  });

  final String restaurantId;

  /// Null leaves the action hidden — the case in a bare widget test.
  final ValueChanged<String>? onEdit;
  final ValueChanged<String>? onLogVisit;

  /// Opens one past visit for editing, by visit id. Null leaves the cards
  /// inert, the same as the other two.
  final ValueChanged<String>? onEditVisit;

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
    unawaited(HapticFeedback.heavyImpact());
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
        final RestaurantUiModel? restaurant = state is DetailLoaded
            ? state.restaurant
            : null;
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
            DetailLoading() => const DetailSkeleton(),
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
              onEditVisit: widget.onEditVisit,
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
    this.onEditVisit,
  });

  final DetailLoaded state;
  final ValueChanged<String> onOpen;

  /// Null leaves the visits section's action hidden — the case in a bare widget
  /// test, the same as [RestaurantDetailScreen.onEdit].
  final ValueChanged<String>? onLogVisit;

  /// See [RestaurantDetailScreen.onEditVisit].
  final ValueChanged<String>? onEditVisit;

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
          // The other end of the journal card's [restaurantHeroTag]: the photo
          // when there is one, and a cuisine-tinted gradient header otherwise.
          // The gradient is keyed to the cuisine accent so the header reads as
          // part of the same visual language as the list card's badge.
          Hero(
            tag: restaurantHeroTag(restaurant.id),
            child: restaurant.photoPath != null
                ? ClipRRect(
                    borderRadius: AppRadius.largeAll,
                    child: Image.file(
                      File(restaurant.photoPath!),
                      width: double.infinity,
                      height: 240,
                      cacheWidth: screenCacheWidth(context),
                      fit: BoxFit.cover,
                      semanticLabel: l10n.detailPhotoDescription,
                      errorBuilder: (
                        BuildContext context,
                        Object error,
                        StackTrace? stack,
                      ) => const SizedBox.shrink(),
                    ),
                  )
                : CuisineHeader(restaurant: restaurant),
          ),
          const SizedBox(height: AppSpacing.lg),
          OverviewCard(
            restaurant: restaurant,
            priceLabel: priceLabel,
            address: address,
            onOpen: onOpen,
          ),
          if (restaurant.hasLinks) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            LinksCard(restaurant: restaurant, onOpen: onOpen),
          ],
          if (state.ratingTrend.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            RatingTrendSection(
              points: state.ratingTrend,
              cuisineKey: restaurant.cuisineKey,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          VisitsSection(
            visits: state.visits,
            cuisineKey: restaurant.cuisineKey,
            // Bound to this restaurant here: the section only has to know
            // whether the action exists at all.
            onAddVisit: onLogVisit == null
                ? null
                : () => onLogVisit!(restaurant.id),
            onEditVisit: onEditVisit,
          ),
        ],
      ),
    );
  }
}
