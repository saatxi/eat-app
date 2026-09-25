import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/app_scope.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../core/widgets/price_range_picker.dart';
import '../../core/widgets/rating_picker.dart';
import 'log_visit_controller.dart';

/// The "log a visit" form: date, rating, price band and a note.
///
/// Opened from the detail screen for one restaurant. Ported from
/// `ui/logvisit/LogVisitScreen.kt`; the photo strip arrives with the photos
/// block.
class LogVisitScreen extends StatefulWidget {
  const LogVisitScreen({super.key, required this.restaurantId});

  final String restaurantId;

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
      _controller = LogVisitController(
        repository: AppScope.of(context).restaurants,
        restaurantId: widget.restaurantId,
      )..addListener(_syncDate);
      _syncDate();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_syncDate);
    _notes.dispose();
    _date.dispose();
    _controller?.dispose();
    super.dispose();
  }

  /// Keeps the read-only date field in step with the state. Done from the
  /// controller's listener rather than in `build`, because writing to a
  /// `TextEditingController` while the tree is building would notify its
  /// `TextField` mid-build.
  void _syncDate() {
    final String next = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(
      DateTime.fromMillisecondsSinceEpoch(_controller!.state.visitDate),
    );
    if (_date.text != next) {
      _date.text = next;
    }
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
            title: Text(l10n.logvisitTitle),
            actions: <Widget>[
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
          body: ListView(
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
