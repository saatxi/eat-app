import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_radius.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../core/widgets/cuisine_visuals.dart';
import '../../core/widgets/price_range_picker.dart';
import '../../data/models/cuisine.dart';
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
  final TextEditingController _tagInput = TextEditingController();

  /// Set once the fields have taken their starting values, so a later rebuild
  /// never overwrites what the user is typing.
  bool _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= RestaurantEditController(
      repository: AppScope.of(context).restaurants,
      restaurantId: widget.restaurantId,
      photoPicker: AppScope.of(context).photoPicker,
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
      _tagInput,
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
                      label: l10n.editFieldCuisine,
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
                    const SizedBox(height: AppSpacing.xl),
                    _SectionLabel(l10n.editSectionTags),
                    if (state.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: <Widget>[
                            for (final String tag in state.tags)
                              InputChip(
                                label: Text(tag),
                                onDeleted: () => controller.removeTag(tag),
                                deleteButtonTooltipMessage:
                                    l10n.editActionRemoveTag(tag),
                              ),
                          ],
                        ),
                      ),
                    TextField(
                      controller: _tagInput,
                      decoration: InputDecoration(
                        labelText: l10n.editFieldTags,
                        border: const OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (String value) {
                        controller.addTag(value);
                        _tagInput.clear();
                      },
                    ),
                    _TagSuggestions(
                      controller: controller,
                      input: _tagInput,
                      addedTags: state.tags,
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
    required this.label,
    required this.placeholder,
    required this.errorText,
    required this.onTap,
  });

  final String? cuisineKey;
  final String label;
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
          decoration: InputDecoration(
            labelText: label,
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

/// Existing tag names matching what is being typed, offered as one-tap chips —
/// nothing on this screen forces a tag to be retyped when it already exists.
class _TagSuggestions extends StatelessWidget {
  const _TagSuggestions({
    required this.controller,
    required this.input,
    required this.addedTags,
  });

  final RestaurantEditController controller;
  final TextEditingController input;
  final List<String> addedTags;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: input,
      builder: (BuildContext context, TextEditingValue value, Widget? child) {
        final String query = value.text.trim().toLowerCase();
        final List<String> suggestions = <String>[
          for (final String suggestion in controller.tagSuggestions)
            if (!addedTags.any(
                  (String tag) => tag.toLowerCase() == suggestion.toLowerCase(),
                ) &&
                (query.isEmpty || suggestion.toLowerCase().contains(query)))
              suggestion,
        ];
        if (suggestions.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final String suggestion in suggestions.take(8))
                ActionChip(
                  label: Text(suggestion),
                  onPressed: () {
                    controller.addTag(suggestion);
                    input.clear();
                  },
                ),
            ],
          ),
        );
      },
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
              child: ClipRRect(
                borderRadius: AppRadius.mediumAll,
                child: Image.file(
                  File(path),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  semanticLabel: l10n.editPhotoPreviewDescription,
                  errorBuilder:
                      (BuildContext context, Object error, StackTrace? stack) =>
                          const SizedBox.shrink(),
                ),
              ),
            ),
          Row(
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(l10n.editActionAddPhoto),
              ),
              if (path != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.editActionRemovePhoto),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
