import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../core/theme/tokens/cuisine_accents.dart';
import '../../core/utils/address_formatter.dart';
import '../../core/widgets/cuisine_visuals.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/tag_pill_row.dart';
import '../../data/share/restaurant_import_reader.dart';
import 'import_controller.dart';

/// The review screen for an incoming shared restaurant file.
///
/// Ported from `ui/importing/RestaurantImportScreen.kt`. It shows the loading
/// state, then either the empty/error states or the list of candidates — new
/// rows first, likely duplicates folded under a collapsible header — each with
/// an Add/Skip/Replace choice, and confirms the lot in one write.
///
/// Nothing is stored until Confirm is pressed: the screen is the whole point of
/// the "check before it lands" rule.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, required this.filePath, this.onDone});

  /// Path to the received file, already resolved to a real file by the sharing
  /// plugin.
  final String filePath;

  /// Called when the screen is finished — the back arrow, the OK on an empty or
  /// failed file, and a completed import all route here. Null in a bare widget
  /// test, where there is nothing to pop back to.
  final VoidCallback? onDone;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  ImportController? _controller;
  bool _duplicatesExpanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      final ImportController controller = ImportController(
        repository: AppScope.of(context).restaurants,
        filePath: widget.filePath,
      );
      _controller = controller;
      controller.load();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _confirm(ImportController controller) async {
    await controller.confirm();
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ImportController controller = _controller!;

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final ImportUiState state = controller.state;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.importTitle),
            leading: IconButton(
              onPressed: widget.onDone,
              tooltip: l10n.actionBack,
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          body: _body(state, controller, l10n),
        );
      },
    );
  }

  Widget _body(
    ImportUiState state,
    ImportController controller,
    AppLocalizations l10n,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final ImportFailureReason? error = state.error;
    if (error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: l10n.importErrorTitle,
        body: _errorBody(l10n, error),
        actionLabel: l10n.actionOk,
        onAction: widget.onDone,
      );
    }
    if (state.candidates.isEmpty) {
      return EmptyState(
        icon: Icons.restaurant_menu,
        title: l10n.importEmptyTitle,
        body: l10n.importEmptyBody,
        actionLabel: l10n.actionOk,
        onAction: widget.onDone,
      );
    }

    // Keep each candidate paired with its index into the controller's list, so
    // a decision row can name the exact row it is changing even after the new
    // and duplicate groups are split apart.
    final List<(int, ImportCandidate)> indexed = <(int, ImportCandidate)>[
      for (int i = 0; i < state.candidates.length; i++)
        (i, state.candidates[i]),
    ];
    final List<(int, ImportCandidate)> fresh = <(int, ImportCandidate)>[
      for (final (int, ImportCandidate) entry in indexed)
        if (entry.$2.duplicateOf == null) entry,
    ];
    final List<(int, ImportCandidate)> duplicates = <(int, ImportCandidate)>[
      for (final (int, ImportCandidate) entry in indexed)
        if (entry.$2.duplicateOf != null) entry,
    ];

    return Column(
      children: <Widget>[
        if (state.skippedInvalidCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: Text(
              l10n.importSkippedInvalid(state.skippedInvalidCount),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              for (final (int, ImportCandidate) entry in fresh)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ImportCandidateCard(
                    candidate: entry.$2,
                    onDecisionChange: (ImportDecision decision) =>
                        controller.onDecisionChange(entry.$1, decision),
                  ),
                ),
              if (duplicates.isNotEmpty) ...<Widget>[
                _DuplicatesHeader(
                  count: duplicates.length,
                  expanded: _duplicatesExpanded,
                  onTap: () => setState(
                    () => _duplicatesExpanded = !_duplicatesExpanded,
                  ),
                ),
                if (_duplicatesExpanded)
                  for (final (int, ImportCandidate) entry in duplicates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _ImportCandidateCard(
                        candidate: entry.$2,
                        onDecisionChange: (ImportDecision decision) =>
                            controller.onDecisionChange(entry.$1, decision),
                      ),
                    ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: state.isImporting ? null : () => _confirm(controller),
              child: Text(l10n.importActionConfirm),
            ),
          ),
        ),
      ],
    );
  }

  static String _errorBody(AppLocalizations l10n, ImportFailureReason reason) =>
      switch (reason) {
        ImportFailureReason.tooLarge => l10n.importErrorTooLarge,
        ImportFailureReason.invalidFile => l10n.importErrorInvalid,
        ImportFailureReason.ioError => l10n.importErrorIo,
      };
}

/// The collapsible row that hides likely duplicates behind one tap.
class _DuplicatesHeader extends StatelessWidget {
  const _DuplicatesHeader({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              AppLocalizations.of(context).importDuplicatesHeader(count),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// One candidate: the restaurant's summary and its Add/Skip/Replace segmented
/// choice.
class _ImportCandidateCard extends StatelessWidget {
  const _ImportCandidateCard({
    required this.candidate,
    required this.onDecisionChange,
  });

  final ImportCandidate candidate;
  final ValueChanged<ImportDecision> onDecisionChange;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final String cuisineType = candidate.restaurant.cuisineType;
    final CuisineTint tint = cuisineTint(context, cuisineType);
    final String? address = formatAddress(
      streetAddress: candidate.restaurant.streetAddress,
      city: candidate.restaurant.city,
      region: candidate.restaurant.region,
      country: candidate.restaurant.country,
    );
    // Replace only makes sense against an existing row, so a new candidate gets
    // two options and a duplicate gets three.
    final List<ImportDecision> options = candidate.duplicateOf != null
        ? <ImportDecision>[
            ImportDecision.skip,
            ImportDecision.add,
            ImportDecision.replace,
          ]
        : <ImportDecision>[ImportDecision.skip, ImportDecision.add];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 24,
                  backgroundColor: tint.container,
                  child: Icon(
                    cuisineIcon(cuisineType),
                    size: 24,
                    color: tint.onContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        candidate.restaurant.name,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        cuisineLabel(l10n, cuisineType),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (address != null)
                        Text(
                          address,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (candidate.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: TagPillRow(tags: candidate.tags),
              ),
            if (candidate.duplicateOf != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.importDuplicateLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: SegmentedButton<ImportDecision>(
                segments: <ButtonSegment<ImportDecision>>[
                  for (final ImportDecision option in options)
                    ButtonSegment<ImportDecision>(
                      value: option,
                      label: Text(_decisionLabel(l10n, option)),
                    ),
                ],
                selected: <ImportDecision>{candidate.decision},
                // The selected fill already marks the choice; the checkmark
                // would eat into a three-way split and clip a longer word.
                showSelectedIcon: false,
                onSelectionChanged: (Set<ImportDecision> selection) =>
                    onDecisionChange(selection.first),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _decisionLabel(
    AppLocalizations l10n,
    ImportDecision decision,
  ) => switch (decision) {
    ImportDecision.add => l10n.importDecisionAdd,
    ImportDecision.skip => l10n.importDecisionSkip,
    ImportDecision.replace => l10n.importDecisionReplace,
  };
}
