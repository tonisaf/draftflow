import 'package:flutter/material.dart';

import '../../account/account_controller.dart';
import '../../l10n/locale_controller.dart';
import '../../sync/sync_engine.dart';
import '../account/sync_panel.dart';
import '../common/status_pill.dart';
import '../theme.dart';
import 'settings_widgets.dart';

/// Account sign-in and current sync state inside Settings.
class SyncSection extends StatefulWidget {
  const SyncSection({super.key, required this.controller});

  final AccountController controller;

  @override
  State<SyncSection> createState() => _SyncSectionState();
}

class _SyncSectionState extends State<SyncSection> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  String? _validationError;
  String? _backupMessage;

  @override
  void initState() {
    super.initState();
    _email.text = widget.controller.account?.email ?? '';
  }

  @override
  void dispose() {
    _email.dispose();
    _password.clear();
    _password.dispose();
    super.dispose();
  }

  String? _validate(BuildContext context) {
    final l10n = context.l10n;
    final email = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return l10n.specifyEmail;
    }
    final password = _password.text;
    if (password.isEmpty) return l10n.enterPassword;
    if (_signUp && password.length < 8) return l10n.passwordMinLength;
    return null;
  }

  Future<void> _submit() async {
    final c = widget.controller;
    if (c.busy) return;
    final validation = _validate(context);
    if (validation != null) {
      setState(() => _validationError = validation);
      return;
    }
    setState(() => _validationError = null);
    FocusScope.of(context).unfocus();
    if (_signUp) {
      await c.signUp(_email.text, _password.text);
    } else {
      await c.signIn(_email.text, _password.text);
    }
    if (mounted) _password.clear();
  }

  Future<void> _conflicts() async {
    await showSyncConflictsDialog(context, widget.controller);
    if (mounted) setState(() {});
  }

  Future<void> _backup() async {
    final result = await saveSyncRecoveryBackup(context, widget.controller);
    if (!mounted || result.isEmpty) return;
    setState(() => _backupMessage = result);
  }

  Widget _signIn(BuildContext context, AccountController c) {
    final l10n = context.l10n;
    final skin = context.skin;
    final error = _validationError ?? c.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (c.account?.requiresSignIn ?? false) ...[
          Text(
            l10n.reauthNotice,
            style: TextStyle(fontSize: 13, color: skin.muted),
          ),
          const SizedBox(height: 12),
        ],
        if (c.account == null) ...[
          SegmentTabs(
            labels: [l10n.syncTabSignIn, l10n.syncTabSignUp],
            index: _signUp ? 1 : 0,
            onChanged: (i) => setState(() {
              _signUp = i == 1;
              _validationError = null;
              _password.clear();
            }),
          ),
          const SizedBox(height: 14),
        ],
        LabeledField(
          controller: _email,
          label: l10n.email,
          enabled: !c.busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
        ),
        LabeledField(
          controller: _password,
          label: l10n.password,
          secret: true,
          enabled: !c.busy,
          autofillHints: [
            _signUp ? AutofillHints.newPassword : AutofillHints.password,
          ],
          onSubmitted: (_) => _submit(),
        ),
        FilledButton(
          onPressed: c.busy ? null : _submit,
          child: Text(_signUp ? l10n.createAccount : l10n.signIn),
        ),
        if (c.busy) ...[
          const SizedBox(height: 10),
          TickerMode(
            enabled: !MediaQuery.disableAnimationsOf(context),
            child: const LinearProgressIndicator(minHeight: 3),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 10),
          StatusPill(
            tone: StatusTone.danger,
            child: Text(error, style: const TextStyle(fontSize: 13)),
          ),
        ],
        if (c.notice != null) ...[
          const SizedBox(height: 10),
          StatusPill(
            tone: StatusTone.warning,
            child: Text(c.notice!, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ],
    );
  }

  Widget _signedIn(BuildContext context, AccountController c) {
    final l10n = context.l10n;
    final skin = context.skin;
    final engine = c.syncEngine;
    final muted = TextStyle(fontSize: 13, color: skin.muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.syncSignedInAs(c.account!.email),
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(syncLabel(context, c), style: muted),
        if (engine?.message != null) Text(engine!.message!, style: muted),
        if (engine != null && engine.pending > 0)
          Text(l10n.waitingToSend(engine.pending), style: muted),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton(
              onPressed:
                  c.busy ||
                      engine == null ||
                      engine.phase == NotesSyncPhase.syncing
                  ? null
                  : engine.sync,
              child: Text(l10n.syncNow),
            ),
            if ((engine?.conflictCount ?? 0) > 0)
              TextButton(
                onPressed: c.busy ? null : _conflicts,
                child: Text(l10n.resolveConflicts),
              ),
            TextButton(
              onPressed: c.busy ? null : _backup,
              child: Text(l10n.backupBeforeConflict),
            ),
            TextButton(
              onPressed: c.busy ? null : c.signOut,
              child: Text(l10n.syncSignOut),
            ),
          ],
        ),
        if (c.busy) ...[
          const SizedBox(height: 8),
          TickerMode(
            enabled: !MediaQuery.disableAnimationsOf(context),
            child: const LinearProgressIndicator(minHeight: 3),
          ),
        ],
        if (c.error != null) ...[
          const SizedBox(height: 10),
          StatusPill(
            tone: StatusTone.danger,
            child: Text(c.error!, style: const TextStyle(fontSize: 13)),
          ),
        ],
        if (_backupMessage != null || c.notice != null) ...[
          const SizedBox(height: 10),
          StatusPill(
            tone: c.notice != null ? StatusTone.warning : StatusTone.success,
            child: Text(
              _backupMessage ?? c.notice!,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (!c.configured) {
          return Text(
            context.l10n.unconfiguredNotice,
            style: TextStyle(fontSize: 13, color: context.skin.muted),
          );
        }
        final needsSignIn =
            c.account == null ||
            c.account!.requiresSignIn ||
            c.syncEngine?.phase == NotesSyncPhase.authRequired;
        return needsSignIn ? _signIn(context, c) : _signedIn(context, c);
      },
    );
  }
}
