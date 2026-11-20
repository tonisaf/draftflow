import 'package:flutter/material.dart';

import '../../account/account_controller.dart';
import '../../account/server_config.dart';
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
  late final _url = TextEditingController(
    text: widget.controller.serverConfig?.url ?? '',
  );
  late final _key = TextEditingController(
    text: widget.controller.serverConfig?.key ?? '',
  );
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _editingServer = false;
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
    _url.dispose();
    _key.dispose();
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

  Widget _serverForm(BuildContext context, AccountController c) {
    final skin = context.skin;
    final error = _validationError ?? c.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Подключение к серверу Supabase',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Укажите адрес вашего проекта Supabase (облачного или self-hosted) и ключ anon.',
          style: TextStyle(fontSize: 13, color: skin.muted),
        ),
        const SizedBox(height: 14),
        LabeledField(
          controller: _url,
          label: 'Адрес проекта Supabase',
          enabled: !c.busy,
          keyboardType: TextInputType.url,
        ),
        LabeledField(
          controller: _key,
          label: 'Ключ anon (API key)',
          secret: true,
          enabled: !c.busy,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              onPressed: c.busy
                  ? null
                  : () async {
                      final url = _url.text.trim();
                      final key = _key.text.trim();
                      if (url.isEmpty) {
                        setState(() => _validationError = 'Укажите адрес сервера Supabase.');
                        return;
                      }
                      if (key.isEmpty) {
                        setState(() => _validationError = 'Укажите ключ anon.');
                        return;
                      }
                      setState(() => _validationError = null);
                      final success = await c.configureServer(url, key);
                      if (mounted && success) {
                        setState(() => _editingServer = false);
                      }
                    },
              child: const Text('Подключить'),
            ),
            ActionPill(
              label: 'Сервер по умолчанию',
              onTap: c.busy
                  ? null
                  : () {
                      _url.text = defaultSupabaseUrl;
                      _key.text = defaultSupabaseAnonKey;
                      setState(() => _validationError = null);
                    },
            ),
            if (c.configured)
              ActionPill(
                label: context.l10n.cancel,
                onTap: c.busy
                    ? null
                    : () {
                        _url.text = c.serverConfig?.url ?? '';
                        _key.text = c.serverConfig?.key ?? '';
                        setState(() {
                          _editingServer = false;
                          _validationError = null;
                        });
                      },
              ),
          ],
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
        Row(
          children: [
            FilledButton(
              onPressed: c.busy ? null : _submit,
              child: Text(_signUp ? l10n.createAccount : l10n.signIn),
            ),
            const Spacer(),
            ActionPill(
              label: c.currentServerHost != null
                  ? 'Сервер: ${c.currentServerHost}'
                  : 'Сменить сервер',
              onTap: c.busy
                  ? null
                  : () => setState(() {
                        _url.text = c.serverConfig?.url ?? '';
                        _key.text = c.serverConfig?.key ?? '';
                        _editingServer = true;
                        _validationError = null;
                      }),
            ),
          ],
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

    String syncStatusText = syncLabel(context, c);
    if (engine?.message != null) syncStatusText += ' • ${engine!.message!}';
    if (engine != null && engine.pending > 0) {
      syncStatusText += ' • ${l10n.waitingToSend(engine.pending)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingRow(
          title: 'Учетная запись',
          subtitle: c.account!.email,
          trailing: ActionPill(
            label: l10n.syncSignOut,
            destructive: true,
            onTap: c.busy ? null : c.signOut,
          ),
        ),
        Divider(height: 25, thickness: 1, color: skin.hairlineBorder),
        SettingRow(
          title: 'Статус синхронизации',
          subtitleWidget: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: (engine?.phase == NotesSyncPhase.error || c.error != null)
                      ? Colors.red
                      : const Color(0xFF10B981), // bg-emerald-500
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  syncStatusText,
                  style: TextStyle(fontSize: 12, color: skin.muted, height: 1.5),
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((engine?.conflictCount ?? 0) > 0) ...[
                ActionPill(
                  label: l10n.resolveConflicts,
                  onTap: c.busy ? null : _conflicts,
                ),
                const SizedBox(width: 8),
              ],
              ActionPill(
                label: l10n.syncNow,
                primary: true,
                onTap: c.busy ||
                        engine == null ||
                        engine.phase == NotesSyncPhase.syncing
                    ? null
                    : engine.sync,
              ),
            ],
          ),
        ),
        Divider(height: 25, thickness: 1, color: skin.hairlineBorder),
        SettingRow(
          title: 'Сервер Supabase',
          subtitle: c.currentServerHost ?? 'Сервер по умолчанию',
          trailing: ActionPill(
            label: 'Сменить',
            onTap: c.busy
                ? null
                : () => setState(() {
                      _url.text = c.serverConfig?.url ?? '';
                      _key.text = c.serverConfig?.key ?? '';
                      _editingServer = true;
                      _validationError = null;
                    }),
          ),
        ),
        Divider(height: 25, thickness: 1, color: skin.hairlineBorder),
        SettingRow(
          title: 'Резервная копия',
          subtitle: 'Локальный снимок базы перед синхронизацией',
          trailing: ActionPill(
            label: 'Создать',
            onTap: c.busy ? null : _backup,
          ),
        ),
        if (c.busy) ...[
          const SizedBox(height: 12),
          TickerMode(
            enabled: !MediaQuery.disableAnimationsOf(context),
            child: const LinearProgressIndicator(minHeight: 3),
          ),
        ],
        if (c.error != null) ...[
          const SizedBox(height: 12),
          StatusPill(
            tone: StatusTone.danger,
            child: Text(c.error!, style: const TextStyle(fontSize: 13)),
          ),
        ],
        if (_backupMessage != null || c.notice != null) ...[
          const SizedBox(height: 12),
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
        if (_editingServer || !c.configured) {
          return _serverForm(context, c);
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
