import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_radius.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../core/widgets/cuisine_visuals.dart';
import '../../core/widgets/price_range_picker.dart';
import '../../data/groups/group_models.dart';
import '../../data/models/cuisine.dart';
import '../../data/sync/shared_writes.dart';
import 'restaurant_edit_controller.dart';
import 'restaurant_edit_state.dart';

/// The add/edit restaurant form.
///
/// Place-level data only — rating, "visited" and notes are recorded on a visit,
/// not here. Ported from `ui/edit/RestaurantEditScreen.kt`; the photo carousel
/// is left to the photos block.
class RestaurantEditScreen extends StatefulWidget {
  const RestaurantEditScreen({super.key, this.restaurantId});

  /// Null adds a new restaurant; set edits that one.
  final String? restaurantId;

  @override
  State<RestaurantEditScreen> createState() => _RestaurantEditScreenState();
}

class _RestaurantEditScreenState extends State<RestaurantEditScreen> {
  RestaurantEditController? _controller;

  final TextEditingController _name = TextEditingController();
  final TextEditingController _streetAddress = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _region = TextEditingController();
  final TextEditingController _country = TextEditingController();
  final TextEditingController _website = TextEditingController();
  final TextEditingController _instagram = TextEditingController();

  /// Set once the fields have taken their starting values, so a later rebuild
  /// never overwrites what the user is typing.
  bool _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppScope scope = AppScope.of(context);
    _controller ??= RestaurantEditController(
      repository: scope.restaurants,
      restaurantId: widget.restaurantId,
      photoPicker: scope.photoPicker,
      sharedWrites: SharedWrites(
        preferences: scope.preferences,
        identity: scope.identity,
      ),
      groups: scope.groupsController?.state.groups ?? const <Group>[],
      initialGroupId: scope.preferences.current.selectedGroupId,
    )..addListener(_prefillOnce);
  }

  @override
  void dispose() {
    _controller?.removeListener(_prefillOnce);
    _controller?.dispose();
    for (final TextEditingController field in <TextEditingController>[
      _name,
      _streetAddress,
      _city,
      _region,
      _country,
      _website,
      _instagram,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  void _prefillOnce() {
    if (_prefilled) {
      return;
    }
    final RestaurantEditState state = _controller!.state;
    if (state.isLoading) {
      return;
    }
    _prefilled = true;
    _name.text = state.name;
    _streetAddress.text = state.streetAddress;
    _city.text = state.city;
    _region.text = state.region;
    _country.text = state.country;
    _website.text = state.website;
    _instagram.text = state.instagram;
  }

  Future<void> _save() async {
    final bool saved = await _controller!.save();
    if (!mounted || !saved) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _pickCuisine() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final Cuisine cuisine in Cuisine.values)
              ListTile(
                leading: Icon(cuisineIcon(cuisine.key)),
                title: Text(cuisine.label(l10n)),
                onTap: () => Navigator.of(sheetContext).pop(cuisine.key),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      _controller!.onCuisineChange(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final RestaurantEditController controller = _controller!;

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final RestaurantEditState state = controller.state;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.restaurantId == null
                  ? l10n.editTitleAdd
                  : l10n.editTitleEdit,
            ),
            actions: <Widget>[
              TextButton(
                onPressed: state.isLoading ? null : _save,
                child: Text(l10n.editActionSave),
              ),
            ],
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: <Widget>[
                    _SectionLabel(l10n.editSectionBasics),
                    _textField(
                      controller: _name,
                      label: l10n.editFieldName,
                      errorText: state.nameError
                          ? l10n.editErrorNameRequired
                          : null,
                      onChanged: controller.onNameChange,
                    ),
                    _CuisineField(
                      cuisineKey: state.cuisineType,
                      placeholder: l10n.editCuisinePlaceholder,
                      errorText:
                          state.cuisineError ? l10n.editErrorCuisineRequired : null,
                      onTap: _pickCuisine,
                    ),
                    _PhotoField(
                      photoPath: state.photoPreviewPath,
                      onAdd: controller.pickPhoto,
                      onRemove: controller.removePhoto,
                    ),
                    if (controller.groups.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.lg),
                      _SectionLabel(l10n.editSectionGroups),
                      _GroupsField(
                        groups: controller.groups,
                        selectedIds: state.selectedGroupIds,
                        onToggle: controller.onToggleGroup,
                      ),
                    ],
                    _textField(
                      controller: _streetAddress,
                      label: l10n.editFieldAddress,
                      onChanged: controller.onStreetAddressChange,
                    ),
                    _textField(
                      controller: _city,
                      label: l10n.editFieldCity,
                      onChanged: controller.onCityChange,
                    ),
                    _textField(
                      controller: _region,
                      label: l10n.editFieldRegion,
                      onChanged: controller.onRegionChange,
                    ),
                    _textField(
                      controller: _country,
                      label: l10n.editFieldCountry,
                      onChanged: controller.onCountryChange,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.lg),
                      child: Text(
                        l10n.editFieldPriceRange,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    PriceRangePicker(
                      priceRange: state.priceRange,
                      onChanged: controller.onPriceRangeChange,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SectionLabel(l10n.editSectionLinks),
                    _textField(
                      controller: _website,
                      label: l10n.editFieldWebsite,
                      errorText:
                          state.websiteError ? l10n.editErrorWebsiteInvalid : null,
                      keyboardType: TextInputType.url,
                      onChanged: controller.onWebsiteChange,
                    ),
                    _textField(
                      controller: _instagram,
                      label: l10n.editFieldInstagram,
                      errorText: state.instagramError
                          ? l10n.editErrorInstagramInvalid
                          : null,
                      onChanged: controller.onInstagramChange,
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
    String? errorText,
    TextInputType? keyboardType,
  }) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: label,
            errorText: errorText,
            border: const OutlineInputBorder(),
          ),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium,
      );
}

/// A tappable field that opens the cuisine picker, styled like the text fields
/// around it so the form reads as one column.
class _CuisineField extends StatelessWidget {
  const _CuisineField({
    required this.cuisineKey,
    required this.placeholder,
    required this.errorText,
    required this.onTap,
  });

  final String? cuisineKey;
  final String placeholder;
  final String? errorText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final String? key = cuisineKey;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          // No `labelText`: on a filled field the label floats above it and
          // overlaps the rounded corner, and the placeholder ("Select a
          // cuisine") already says what the field is for.
          decoration: InputDecoration(
            errorText: errorText,
            border: const OutlineInputBorder(),
          ),
          child: Row(
            children: <Widget>[
              if (key != null) ...<Widget>[
                Icon(cuisineIcon(key), size: 18),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  key == null ? placeholder : cuisineLabel(l10n, key),
                  style: key == null
                      ? theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )
                      : theme.textTheme.bodyLarge,
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Shared with" field: one dropdown that opens a checkable list of the
/// user's groups, so a restaurant can be shared into several at once. Styled
/// like [_CuisineField] so the form reads as one column.
class _GroupsField extends StatelessWidget {
  const _GroupsField({
    required this.groups,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<Group> groups;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final List<String> selectedNames = <String>[
      for (final Group group in groups)
        if (selectedIds.contains(group.id)) group.name,
    ];
    final bool anySelected = selectedNames.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: MenuAnchor(
        menuChildren: <Widget>[
          for (final Group group in groups)
            // CheckboxMenuButton keeps the menu open as items are ticked, so
            // several groups can be chosen in one go.
            CheckboxMenuButton(
              value: selectedIds.contains(group.id),
              onChanged: (bool? _) => onToggle(group.id),
              child: Text(group.name),
            ),
        ],
        builder:
            (BuildContext context, MenuController controller, Widget? child) {
              return InkWell(
                onTap: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          anySelected
                              ? selectedNames.join(', ')
                              : l10n.editGroupsNotShared,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: anySelected
                              ? theme.textTheme.bodyLarge
                              : theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              );
            },
      ),
    );
  }
}

/// The restaurant's one photo: a preview when there is one, and the buttons that
/// add, replace or remove it. Everything is staged in the controller and only
/// written on save, so backing out of the form changes nothing.
class _PhotoField extends StatelessWidget {
  const _PhotoField({
    required this.photoPath,
    required this.onAdd,
    required this.onRemove,
  });

  final String? photoPath;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? path = photoPath;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (path != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Stack(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: AppRadius.mediumAll,
                    child: Image.file(
                      File(path),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      semanticLabel: l10n.editPhotoPreviewDescription,
                      errorBuilder:
                          (
                            BuildContext context,
                            Object error,
                            StackTrace? stack,
                          ) => const SizedBox.shrink(),
                    ),
                  ),
                  // Icon-only, over the photo it acts on: two labelled buttons
                  // side by side overflow the row in the longer locales.
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: IconButton.filledTonal(
                      onPressed: onRemove,
                      tooltip: l10n.editActionRemovePhoto,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ],
              ),
            ),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(l10n.editActionAddPhoto),
          ),
        ],
      ),
    );
  }
}
