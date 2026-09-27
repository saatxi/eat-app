import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/app_scope.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../data/groups/invite_link.dart';
import '../../data/groups/invite_models.dart';
import 'groups_controller.dart';
import 'join_controller.dart';

/// The joining side of an invitation: type or paste a code, or scan its QR, then
/// pick the display name the group will know you by.
///
/// A deep link (`eatapp://join/<token>`) arrives as [initialToken], pre-filling
/// the field so the user only has to confirm their name and tap Join.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, this.initialToken});

  /// The token a deep link carried, or null when the screen was opened by hand.
  final String? initialToken;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  JoinController? _controller;
  late final TextEditingController _code = TextEditingController(
    text: widget.initialToken ?? '',
  );
  final TextEditingController _name = TextEditingController();
  String? _codeError;
  String? _nameError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppScope scope = AppScope.of(context);
    _controller ??= JoinController(
      gateway: scope.invites,
      identity: scope.identity,
    );
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final String? token = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext context) => const _ScannerScreen(),
      ),
    );
    if (token == null || !mounted) {
      return;
    }
    setState(() {
      _code.text = token;
      _codeError = null;
    });
  }

  Future<void> _join() async {
    // Everything off the context before the first await.
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final GroupsController? groups = AppScope.of(context).groupsController;

    final String? token = inviteTokenFromText(_code.text);
    final String name = _name.text.trim();
    setState(() {
      _codeError = token == null ? l10n.groupsJoinInvalidCode : null;
      _nameError = name.isEmpty ? l10n.groupsJoinNameRequired : null;
    });
    if (token == null || name.isEmpty) {
      return;
    }

    final JoinController controller = _controller!;
    if (!await controller.join(token: token, displayName: name)) {
      // The failure is on the controller's state and drawn under the fields.
      return;
    }
    final JoinedGroup? joined = controller.state.joined;
    if (joined == null) {
      return;
    }
    // Refresh the roster of groups and select the one just joined, so the list
    // switches to it on the way back.
    await groups?.load();
    await groups?.select(joined.groupId);
    if (!mounted) {
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.groupsJoinSuccess(joined.groupName))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final JoinController controller = _controller!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupsJoinTitle)),
      body: ListenableBuilder(
        listenable: controller,
        builder: (BuildContext context, Widget? child) {
          final JoinState state = controller.state;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: <Widget>[
              TextField(
                controller: _code,
                autofocus: widget.initialToken == null,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: l10n.groupsJoinCodeLabel,
                  hintText: l10n.groupsJoinCodeHint,
                  errorText: _codeError,
                  suffixIcon: IconButton(
                    onPressed: _scan,
                    tooltip: l10n.groupsJoinScan,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _join(),
                decoration: InputDecoration(
                  labelText: l10n.groupsJoinNameLabel,
                  hintText: l10n.groupsJoinNameHint,
                  errorText: _nameError,
                ),
              ),
              if (state.failure != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _messageFor(state.failure!, l10n),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: state.isJoining ? null : _join,
                child: state.isJoining
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.groupsJoinAction),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Turns a join failure into the message the screen shows.
String _messageFor(InviteFailure failure, AppLocalizations l10n) =>
    switch (failure) {
      InviteFailure.inviteNotFound => l10n.groupsJoinNotFound,
      InviteFailure.alreadyMember => l10n.groupsJoinAlreadyMember,
      InviteFailure.rateLimited => l10n.groupsJoinRateLimited,
      InviteFailure.network => l10n.groupsJoinNetwork,
      InviteFailure.invalidRequest => l10n.groupsJoinInvalidCode,
      InviteFailure.unauthenticated ||
      InviteFailure.notOwner ||
      InviteFailure.internal => l10n.groupsJoinFailed,
    };

/// A full-screen QR reader. Pops the first token it recognises, or null if the
/// user backs out.
class _ScannerScreen extends StatefulWidget {
  const _ScannerScreen();

  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  final MobileScannerController _scanner = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    unawaited(_scanner.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) {
      return;
    }
    for (final Barcode barcode in capture.barcodes) {
      final String? raw = barcode.rawValue;
      final String? token = raw == null ? null : inviteTokenFromText(raw);
      if (token != null) {
        _handled = true;
        Navigator.of(context).pop(token);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupsJoinScannerTitle)),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(
            controller: _scanner,
            onDetect: _onDetect,
            errorBuilder:
                (BuildContext context, MobileScannerException error) =>
                    _ScannerFailure(error: error),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    l10n.groupsJoinScannerHint,
                    style: const TextStyle(color: Colors.white),
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

/// The scanner's error state — most often a denied camera permission.
class _ScannerFailure extends StatelessWidget {
  const _ScannerFailure({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool denied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          denied
              ? l10n.groupsJoinScannerPermission
              : l10n.groupsJoinScannerError,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
