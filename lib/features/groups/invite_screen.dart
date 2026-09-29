import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/app_scope.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/tokens/app_spacing.dart';
import '../../data/groups/group_models.dart';
import '../../data/groups/invite_link.dart';
import '../../data/groups/invite_models.dart';
import 'invite_controller.dart';

/// The owner-side invitation screen: mint a token for [group] and show it as a
/// scannable QR and a hand-copyable code.
///
/// Reachable only for a group the signed-in user owns — the members screen gates
/// the entry on the role, and `create-invite` re-checks it server-side.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key, required this.group});

  final Group group;

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  InviteController? _controller;
  bool _created = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppScope scope = AppScope.of(context);
    _controller ??= InviteController(
      groupId: widget.group.id,
      gateway: scope.invites,
      identity: scope.identity,
    );
    // One invitation on open, so the QR is on screen the moment the screen is.
    if (!_created) {
      _created = true;
      unawaited(_controller!.create());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _regenerate() => _controller!.create();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final InviteController controller = _controller!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupsInviteTitle(widget.group.name))),
      body: ListenableBuilder(
        listenable: controller,
        builder: (BuildContext context, Widget? child) {
          final InviteState state = controller.state;
          final Invite? invite = state.invite;
          if (invite == null) {
            return state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _Failure(onRetry: _regenerate);
          }
          return _Ready(
            invite: invite,
            isRefreshing: state.isLoading,
            onRegenerate: _regenerate,
          );
        },
      ),
    );
  }
}

/// The invitation itself: the QR, the code and the actions on it.
class _Ready extends StatelessWidget {
  const _Ready({
    required this.invite,
    required this.isRefreshing,
    required this.onRegenerate,
  });

  final Invite invite;
  final bool isRefreshing;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String link = inviteLink(invite.token);
    // Round up: a just-minted seven-day invitation is seven days, not six and a
    // fraction.
    final int days = (invite.expiresAt.difference(DateTime.now()).inHours / 24)
        .ceil()
        .clamp(0, 9999);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: <Widget>[
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSpacing.md),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: QrImageView(
                  data: link,
                  size: 240,
                  backgroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.groupsInviteDetails(days, invite.maxUses),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: <Widget>[
              Text(
                l10n.groupsInviteCodeLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const Spacer(),
              SelectableText(
                invite.token,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                ),
              ),
              IconButton(
                onPressed: () => _copy(context, invite.token, l10n),
                tooltip: l10n.groupsInviteCopied,
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          TextButton.icon(
            onPressed: isRefreshing ? null : onRegenerate,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.groupsInviteNewLink),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(
    BuildContext context,
    String text,
    AppLocalizations l10n,
  ) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.groupsInviteCopied)));
  }
}

/// Shown when minting an invitation failed and there is none to show yet.
class _Failure extends StatelessWidget {
  const _Failure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.groupsInviteCreateFailed,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: onRetry,
              child: Text(l10n.groupsInviteRetry),
            ),
          ],
        ),
      ),
    );
  }
}
