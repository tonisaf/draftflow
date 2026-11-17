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

        return SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Palette.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(UiRadius.action),
                        ),
                        child: const Icon(
                          AppIcons.cloudDownload,
                          color: Palette.accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: UiSpace.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DraftFlow Updates',
                              style: TextStyle(
                                fontSize: UiType.title,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Текущая версия: v$currentAppVersion',
                              style: TextStyle(
                                fontSize: UiType.caption,
                                color: skin.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildCheckButton(status),
                    ],
                  ),

                  if (status == UpdateCheckStatus.upToDate) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: Palette.success,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'У вас установлена самая актуальная версия',
                          style: TextStyle(
                            fontSize: UiType.caption,
                            color: skin.muted,
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (status == UpdateCheckStatus.error) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Не удалось проверить обновления: ${_service.errorMessage ?? "Сеть недоступна"}',
                            style: const TextStyle(
                              fontSize: UiType.micro,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (release != null && _service.hasUpdate) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: skin.hover,
                        borderRadius: BorderRadius.circular(UiRadius.compact),
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
                            const SizedBox(height: 6),
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
                                    const Text(
                                      'Загрузка обновления...',
                                      style: TextStyle(fontSize: UiType.micro),
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
                                  backgroundColor: skin.surface,
                                  color: Palette.accent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                          ] else if (status == UpdateCheckStatus.downloaded) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _service.openDownloadedFile(),
                                    icon: const Icon(Icons.folder_open, size: 16),
                                    label: const Text('Открыть файл обновления'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Palette.accent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(UiRadius.action),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _service.downloadUpdate(release),
                                    icon: const Icon(Icons.download, size: 16),
                                    label: Text(
                                      asset != null ? 'Скачать (${asset.name})' : 'Скачать обновление',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Palette.accent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(UiRadius.action),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => _service.openReleasePage(),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: skin.text,
                                    side: BorderSide(color: skin.hairlineBorder),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(UiRadius.action),
                                    ),
                                  ),
                                  child: const Text('GitHub'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
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

    return TextButton(
      onPressed: () => _service.checkForUpdates(manual: true),
      style: TextButton.styleFrom(
        foregroundColor: Palette.accent,
        backgroundColor: Palette.accent.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UiRadius.action),
        ),
      ),
      child: const Text(
        'Проверить',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
