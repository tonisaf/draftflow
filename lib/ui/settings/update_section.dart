import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/app_update_service.dart';
import '../common/app_icons.dart';
import '../common/status_pill.dart';
import '../theme.dart';
import 'settings_widgets.dart';

class AppUpdateSection extends StatefulWidget {
  final AppUpdateService? updateService;

  const AppUpdateSection({super.key, this.updateService});

  @override
  State<AppUpdateSection> createState() => _AppUpdateSectionState();
}

class _AppUpdateSectionState extends State<AppUpdateSection> {
  late final AppUpdateService _service;
  bool _ownsService = false;

  @override
  void initState() {
    super.initState();
    if (widget.updateService != null) {
      _service = widget.updateService!;
    } else {
      _service = AppUpdateService();
      _ownsService = true;
    }
  }

  @override
  void dispose() {
    if (_ownsService) {
      _service.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        final status = _service.status;
        final release = _service.latestRelease;
        final asset = release?.platformAsset();

        String statusSubtitle;
        if (status == UpdateCheckStatus.upToDate) {
          statusSubtitle = 'У вас установлена самая актуальная версия';
        } else if (status == UpdateCheckStatus.error) {
          statusSubtitle = 'Ошибка проверки сети: ${_service.errorMessage ?? "Сеть недоступна"}';
        } else if (status == UpdateCheckStatus.checking) {
          statusSubtitle = 'Проверка доступных обновлений…';
        } else {
          statusSubtitle = 'Нажмите «Проверить» для поиска новой версии';
        }

        return SettingsCard(
          children: [
            SettingRow(
              title: 'DraftFlow Updates',
              subtitle: 'Текущая версия: v$currentAppVersion • $statusSubtitle',
              trailing: _buildCheckButton(status),
            ),
            if (release != null && _service.hasUpdate)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: skin.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: skin.hairlineBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        StatusPill(
                          tone: StatusTone.success,
                          child: Text('Доступно: v${release.version}'),
                        ),
                        const Spacer(),
                        if (asset != null && asset.size > 0)
                          Text(
                            asset.formattedSize(),
                            style: TextStyle(
                              fontSize: UiType.micro,
                              color: skin.muted,
                            ),
                          ),
                      ],
                    ),
                    if (release.name.isNotEmpty && release.name != release.tagName) ...[
                      const SizedBox(height: 8),
                      Text(
                        release.name,
                        style: const TextStyle(
                          fontSize: UiType.body,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (release.notes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        release.notes,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: UiType.caption,
                          color: skin.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (status == UpdateCheckStatus.downloading) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _service.downloadProgress >= 1.0
                                    ? 'Подготовка к установке…'
                                    : 'Загрузка обновления...',
                                style: const TextStyle(fontSize: UiType.micro),
                              ),
                              Text(
                                '${(_service.downloadProgress * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: UiType.micro,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: _service.downloadProgress,
                            backgroundColor: skin.surfaceSubtle,
                            color: Palette.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ] else if (status == UpdateCheckStatus.installing) ...[
                      Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Palette.accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Установка обновления и перезапуск…',
                            style: TextStyle(
                              fontSize: UiType.caption,
                              color: skin.text,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ] else if (status == UpdateCheckStatus.downloaded) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionPill(
                            label: 'Перезапустить и обновить',
                            primary: true,
                            icon: Icons.restart_alt,
                            onTap: () => _service.installAndRestart(),
                          ),
                          ActionPill(
                            label: 'Файл',
                            icon: Icons.folder_open,
                            onTap: () => _service.openDownloadedFile(),
                          ),
                        ],
                      ),
                    ] else if (asset == null) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionPill(
                            label: 'Сборка формируется на GitHub…',
                            icon: Icons.hourglass_top,
                            onTap: () => _service.openReleasePage(),
                          ),
                          ActionPill(
                            label: 'GitHub',
                            onTap: () => _service.openReleasePage(),
                          ),
                        ],
                      ),
                    ] else ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionPill(
                            label: Platform.isMacOS || Platform.isWindows
                                ? 'Обновить и перезапустить'
                                : 'Скачать (${asset.name})',
                            primary: true,
                            icon: Icons.system_update_alt,
                            onTap: () => _service.downloadAndInstall(release),
                          ),
                          ActionPill(
                            label: 'GitHub',
                            onTap: () => _service.openReleasePage(),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCheckButton(UpdateCheckStatus status) {
    if (status == UpdateCheckStatus.checking) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2, color: Palette.accent),
      );
    }

    return ActionPill(
      label: 'Проверить',
      onTap: () => _service.checkForUpdates(manual: true),
    );
  }
}
