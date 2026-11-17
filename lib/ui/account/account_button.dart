import '../common/app_dialog.dart';
import '../common/app_icons.dart';
import '../settings/settings_dialog.dart';

import 'package:flutter/material.dart';

import '../../account/account_controller.dart';
import '../../account/account_scope.dart';
import '../../l10n/locale_controller.dart';
import '../../sync/sync_engine.dart';
import '../common/modern_dialog.dart';
import '../theme.dart';
import 'sync_panel.dart';

class AccountButton extends StatelessWidget {
  const AccountButton({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AccountScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UiSpace.s10,
        vertical: UiSpace.s4,
      ),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: context.skin.muted,
          padding: const EdgeInsets.symmetric(
            horizontal: UiSpace.s8,
            vertical: UiSpace.s6,
          ),
          minimumSize: const Size(0, DesktopUx.sidebarRowHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UiRadius.sidebarRow),
          ),
        ),
        onPressed: controller.busy
            ? null
            : () => showAppDialog<void>(
                context: context,
                animationStyle: Motion.dialogStyle(context),
                barrierColor: context.skin.scrim,
                builder: (_) => _AccountDialog(controller: controller),
              ),
        icon: Icon(
          controller.account == null
              ? AppIcons.person
              : AppIcons.personCropCircle,
          size: UiSpace.s16,
        ),
        label: Text(
          controller.account == null
              ? context.l10n.signInToAccount
              : '${controller.account!.email} · ${syncLabel(context, controller)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: UiType.body),
        ),
      ),
    );
  }
}

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({required this.controller});
  final AccountController controller;
  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _register = false;
  @override
  void initState() {
    super.initState();
    _email.text = widget.controller.account?.email ?? '';
  }

  Future<void> _submit() async {
    if (widget.controller.busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final success = _register
        ? await widget.controller.signUp(_email.text, _password.text)
        : await widget.controller.signIn(_email.text, _password.text);
    if (!mounted) return;
    _password.clear();
    if (success && widget.controller.account != null) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _password.clear();
    _password.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      return PopScope(
        canPop: !c.busy,
        child: ModernDialog(
          title: c.account == null
              ? context.l10n.accountTitle
              : context.l10n.yourAccount,
          icon: AppIcons.person,
          allowClose: !c.busy,
          content: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  c.account == null
                      ? context.l10n.accountGuestNotice
                      : c.account!.email,
                  style: TextStyle(
                    color: context.skin.text,
                    fontSize: UiType.body,
                  ),
                ),
                const SizedBox(height: UiSpace.s12),
                if (c.account != null) SyncPanel(controller: c),
                if (c.account?.requiresSignIn ?? false) ...[
                  const SizedBox(height: UiSpace.s12),
                  Text(context.l10n.reauthNotice),
                ],
                if (!c.configured) ...[
                  const SizedBox(height: UiSpace.s12),
                  Text(context.l10n.unconfiguredNotice),
                  const SizedBox(height: UiSpace.s12),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      showSettings(context, initialTab: 1);
                    },
                    icon: const Icon(Icons.settings, size: UiSpace.s16),
                    label: const Text('Настроить сервер'),
                  ),
                ] else if (c.account == null ||
                    c.account!.requiresSignIn ||
                    c.syncEngine?.phase == NotesSyncPhase.authRequired) ...[
                  const SizedBox(height: UiSpace.s16),
                  TextFormField(
                    controller: _email,
                    selectAllOnFocus: false,
                    enabled: !c.busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: modernInputDecoration(
                      skin: context.skin,
                      hintText: context.l10n.email,
                    ),
                    validator: (v) =>
                        v != null &&
                            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(v.trim())
                        ? null
                        : context.l10n.specifyEmail,
                  ),
                  const SizedBox(height: UiSpace.s10),
                  TextFormField(
                    controller: _password,
                    selectAllOnFocus: false,
                    enabled: !c.busy,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    autofillHints: [
                      _register
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    decoration: modernInputDecoration(
                      skin: context.skin,
                      hintText: context.l10n.password,
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? context.l10n.enterPassword
                        : _register && v.length < 8
                        ? context.l10n.passwordMinLength
                        : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: UiSpace.s12),
                  FilledButton(
                    onPressed: c.busy ? null : _submit,
                    child: Text(
                      _register
                          ? context.l10n.createAccount
                          : context.l10n.signIn,
                    ),
                  ),
                  if (c.account == null)
                    TextButton(
                      onPressed: c.busy
                          ? null
                          : () => setState(() {
                              _register = !_register;
                              _password.clear();
                            }),
                      child: Text(
                        _register
                            ? context.l10n.alreadyHaveAccount
                            : context.l10n.createAccount,
                      ),
                    ),
                ],
                if (c.account != null) ...[
                  const SizedBox(height: UiSpace.s16),
                  TextButton(
                    onPressed: c.busy
                        ? null
                        : () async {
                            final success = await c.signOut();
                            if (success && context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                    child: Text(context.l10n.logOutAndOpenLocal),
                  ),
                ],
                if (c.busy)
                  TickerMode(
                    enabled: !MediaQuery.disableAnimationsOf(context),
                    child: LinearProgressIndicator(),
                  ),
                if (c.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: UiSpace.s12),
                    child: Text(
                      c.error!,
                      style: TextStyle(
                        color: context.skin.destructive,
                        fontSize: UiType.body,
                      ),
                    ),
                  ),
                if (c.notice != null)
                  Padding(
                    padding: const EdgeInsets.only(top: UiSpace.s12),
                    child: Text(
                      c.notice!,
                      style: TextStyle(
                        color: context.skin.text,
                        fontSize: UiType.body,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
