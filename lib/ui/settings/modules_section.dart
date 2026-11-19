import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import '../../data/notes_repository.dart';
import '../../modules/core/app_module.dart';
import '../../modules/core/module_scope.dart';
import '../theme.dart';

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
            style: TextStyle(fontSize: 12, color: skin.faint, height: 1.4),
          ),
        ),
        for (final module in moduleManager.allModules) ...[
          _buildModuleCard(context, module, moduleManager, skin),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildModuleCard(
    BuildContext context,
    AppModule module,
    dynamic moduleManager,
    Skin skin,
  ) {
    final isEnabled = moduleManager.isEnabled(module.id);

    return Container(
      decoration: BoxDecoration(
        color: skin.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: skin.hairlineBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row with toggle
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? Palette.accent.withValues(alpha: 0.15)
                        : skin.hover,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    module.icon,
                    size: 20,
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: skin.text,
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
                CupertinoSwitch(
                  value: isEnabled,
                  activeColor: Palette.accent,
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
          ),

          // If enabled & repository available, show module settings
          if (isEnabled && widget.repository != null) ...[
            Divider(height: 1, color: skin.divider),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: module.buildSettings(
                context,
                repository: widget.repository!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
