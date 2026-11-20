import 'package:flutter/material.dart';
import '../../data/notes_repository.dart';
import '../../modules/core/app_module.dart';
import '../../modules/core/module_scope.dart';
import '../theme.dart';
import 'settings_widgets.dart';

class ModulesSettingsTab extends StatefulWidget {
  final NotesRepository? repository;

  const ModulesSettingsTab({super.key, this.repository});

  @override
  State<ModulesSettingsTab> createState() => _ModulesSettingsTabState();
}

class _ModulesSettingsTabState extends State<ModulesSettingsTab> {
  final Set<String> _expandedModuleIds = {};

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final moduleManager = AppModuleScope.maybeOf(context);

    if (moduleManager == null || moduleManager.allModules.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Нет доступных модулей.',
            style: TextStyle(color: skin.muted),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Подключайте внешние сервисы и медиатеки. Включенные модули появляются отдельным пунктом в боковой панели.',
            style: TextStyle(fontSize: 13, color: skin.muted, height: 1.4),
          ),
        ),
        SettingsCard(
          children: [
            for (final module in moduleManager.allModules)
              _buildModuleItem(context, module, moduleManager, skin),
          ],
        ),
      ],
    );
  }

  Widget _buildModuleItem(
    BuildContext context,
    AppModule module,
    dynamic moduleManager,
    Skin skin,
  ) {
    final isEnabled = moduleManager.isEnabled(module.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isEnabled
                    ? Palette.accent.withValues(alpha: 0.12)
                    : (skin.isDark ? const Color(0xFF26282E) : const Color(0xFFF1F3F5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                module.icon,
                size: 18,
                color: isEnabled ? Palette.accent : skin.muted,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    module.description,
                    style: TextStyle(fontSize: 12, color: skin.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            MacOSToggleSwitch(
              value: isEnabled,
              onChanged: (val) {
                moduleManager.setEnabled(module.id, val);
                setState(() {
                  if (val) {
                    _expandedModuleIds.add(module.id);
                  }
                });
              },
            ),
          ],
        ),
        if (isEnabled && widget.repository != null) ...[
          const SizedBox(height: 12),
          Divider(height: 1, color: skin.hairlineBorder),
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 50),
            child: module.buildSettings(
              context,
              repository: widget.repository!,
            ),
          ),
        ],
      ],
    );
  }
}
