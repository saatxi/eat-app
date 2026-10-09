import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_radius.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../core/widgets/delete_confirm_dialog.dart';
import '../../core/widgets/price_range_picker.dart';
import '../../core/widgets/rating_picker.dart';
import '../../data/sync/shared_writes.dart';
import 'log_visit_controller.dart';

/// The visit form: date, rating, price band, a note and the visit's photos.
///
/// Opened from the detail screen, either to log a new visit for a restaurant
/// or — with [visitId] given — to edit one already in its history, which is the
/// same form prefilled plus a delete action. Ported from
/// `ui/logvisit/LogVisitScreen.kt`.
class LogVisitScreen extends StatefulWidget {
  const LogVisitScreen({super.key, required this.restaurantId, this.visitId});

  final String restaurantId;

  /// The visit to edit, or null to log a new one.
  final String? visitId;

  @override
  State<LogVisitScreen> createState() => _LogVisitScreenState();
}

class _LogVisitScreenState extends State<LogVisitScreen> {
  LogVisitController? _controller;
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _date = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      final AppScope scope = AppScope.of(context);
      _controller = LogVisitController(
        repository: scope.restaurants,
        restaurantId: widget.restaurantId,
        visitId: widget.visitId,
        photoPicker: scope.photoPicker,
        sharedWrites: SharedWrites(
          preferences: scope.preferences,
          identity: scope.identity,
        ),
      )..addListener(_syncForm);
      _syncForm();
      // Edit mode only: fills the form from the stored visit, after which
      // `_syncForm` copies the loaded note and date into their fields.
      unawaited(_controller!.load());
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_syncForm);
    _notes.dispose();
    _date.dispose();
    _controller?.dispose();
    super.dispose();
  }

  /// The last note this screen wrote into [_notes], so a later edit of the
  /// field is never overwritten by the value it produced.
  String? _lastPushedNotes;

  /// Keeps the read-only date field and the note in step with the state. Done
  /// from the controller's listener rather than in `build`, because writing to
  /// a `TextEditingController` while the tree is building would notify its
  /// `TextField` mid-build.
  ///
  /// The note is only pushed when the two have actually diverged, which in
  /// practice means the one load in edit mode: typing already moves the state
  /// from the field, and writing it back on every keystroke would fight the
  /// cursor.
  void _syncForm() {
    final LogVisitState state = _controller!.state;
    final String next = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(DateTime.fromMillisecondsSinceEpoch(state.visitDate));
    if (_date.text != next) {
      _date.text = next;
    }
    if (_notes.text != state.notes && state.notes != _lastPushedNotes) {
      _lastPushedNotes = state.notes;
      _notes.text = state.notes;
    }
  }

  /// Confirms, then removes the visit and leaves. Edit mode only.
  Future<void> _delete() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool confirmed = await showDeleteConfirmDialog(
      context,
      title: l10n.logvisitDeleteConfirmTitle,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await HapticFeedback.heavyImpact();
    await _controller!.delete();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
    await _controller!.save();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _pickDate(int currentMillis) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.fromMillisecondsSinceEpoch(currentMillis),
      firstDate: DateTime(2000),
      // A visit can be logged for today, and a day of slack covers a device in
      // a timezone ahead of the picker's own "today".
      lastDate: now.add(const Duration(days: 1)),
    );
    if (picked != null) {
      _controller!.onDateChange(picked.millisecondsSinceEpoch);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LogVisitController controller = _controller!;

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final LogVisitState state = controller.state;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              controller.isEditing ? l10n.logvisitEditTitle : l10n.logvisitTitle,
            ),
            actions: <Widget>[
              if (controller.isEditing && !state.isSaving)
                IconButton(
                  onPressed: _delete,
                  tooltip: l10n.logvisitActionDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              if (state.isSaving)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  onPressed: _save,
                  tooltip: l10n.logvisitActionSave,
                  icon: const Icon(Icons.check),
                ),
            ],
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: <Widget>[
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                l10n.logvisitFieldDate,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: AppSpacing.xs),
                                child: TextField(
                                  readOnly: true,
                                  controller: _date,
                                  onTap: () => _pickDate(state.visitDate),
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                l10n.logvisitFieldRating,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: AppSpacing.xs),
                                child: RatingPicker(
                                  rating: state.rating,
                                  onChanged: controller.onRatingChange,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                l10n.logvisitFieldPrice,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              PriceRangePicker(
                                priceRange: state.priceRange,
                                onChanged: controller.onPriceRangeChange,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              TextField(
                                controller: _notes,
                                onChanged: controller.onNotesChange,
                                minLines: 3,
                                maxLines: 6,
                                decoration: InputDecoration(
                                  labelText: l10n.logvisitFieldNotes,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _PhotoStrip(
                                photos: state.photos,
                                onAdd: controller.pickPhoto,
                                onRemove: controller.removePhoto,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                ),
        );
      },
    );
  }
}

/// The visit's photos: a horizontal strip of thumbnails, each removable, with
/// an "add" button underneath. Stored photos and just-picked ones are drawn the
/// same; nothing is written either way until the visit is saved.
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.photos,
    required this.onAdd,
    required this.onRemove,
  });

  final List<VisitPhoto> photos;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (photos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (BuildContext context, int index) {
                  final String path = photos[index].path;
                  return Stack(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: AppRadius.smallAll,
                        child: Image.file(
                          File(path),
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          semanticLabel: l10n.logvisitPhotoDescription,
                          errorBuilder:
                              (
                                BuildContext context,
                                Object error,
                                StackTrace? stack,
                              ) => const SizedBox.shrink(),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton.filledTonal(
                          onPressed: () => onRemove(path),
                          tooltip: l10n.logvisitActionRemovePhoto,
                          icon: const Icon(Icons.cancel),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text(l10n.logvisitActionAddPhoto),
        ),
      ],
    );
  }
}
