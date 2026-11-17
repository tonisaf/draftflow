import 'package:flutter/material.dart';
import '../../../../ui/theme.dart';
import '../../core/url_utils.dart';
import '../services/tmdb_api_client.dart';
import '../services/tmdb_config_service.dart';
import '../services/tmdb_database_sync.dart';
import '../services/kinopoisk_service.dart';

class TmdbSettingsView extends StatefulWidget {
  final TmdbApiClient apiClient;
  final TmdbConfigService configService;
  final TmdbDatabaseSync syncService;

  const TmdbSettingsView({
    super.key,
    required this.apiClient,
    required this.configService,
    required this.syncService,
  });

  @override
  State<TmdbSettingsView> createState() => _TmdbSettingsViewState();
}

class _TmdbSettingsViewState extends State<TmdbSettingsView> {
  late final TextEditingController _tokenController;
  late final TextEditingController _kpTokenController;
  bool _isSavingToken = false;
  bool _isSavingKpToken = false;
  bool _isConnecting = false;
  bool _isSyncing = false;
  bool _isSyncingKp = false;
  String _kpSyncProgress = '';

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: widget.configService.apiToken ?? '');
    _kpTokenController = TextEditingController(text: widget.configService.kpApiToken ?? '');
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _kpTokenController.dispose();
    super.dispose();
  }

  Future<void> _saveToken() async {
    setState(() => _isSavingToken = true);
    await widget.configService.setApiToken(_tokenController.text);
    if (mounted) {
      setState(() => _isSavingToken = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API токен TMDB успешно сохранен!')),
      );
    }
  }

  Future<void> _saveKpToken() async {
    setState(() => _isSavingKpToken = true);
    await widget.configService.setKpApiToken(_kpTokenController.text);
    if (mounted) {
      setState(() => _isSavingKpToken = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API токен Кинопоиска успешно сохранен!')),
      );
    }
  }

  Future<void> _syncKpRatings() async {
    if (!widget.configService.hasKpToken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала укажите и сохраните токен Кинопоиска.')),
      );
      return;
    }

    setState(() {
      _isSyncingKp = true;
      _kpSyncProgress = 'Загрузка списка фильмов...';
    });

    try {
      final items = await widget.syncService.loadLocalItems();
      if (items.isEmpty) {
        if (mounted) {
          setState(() {
            _isSyncingKp = false;
            _kpSyncProgress = '';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('В медиатеке пока нет фильмов для обновления.')),
          );
        }
        return;
      }

      final kpService = KinopoiskService();
      int updatedCount = 0;
      final total = items.length;

      for (int i = 0; i < total; i++) {
        final item = items[i];
        if (!mounted) break;

        setState(() {
          _kpSyncProgress = 'Обновление ${i + 1} из $total: «${item.title}»...';
        });

        // 1. If item doesn't have imdbId and we have TMDB token, fetch details to get imdbId
        String? imdbId = item.imdbId;
        if (imdbId == null && widget.configService.hasApiToken) {
          try {
            final details = await widget.apiClient.getDetails(
              apiToken: widget.configService.apiToken!,
              id: item.id,
              mediaType: item.mediaType,
            );
            imdbId = details.imdbId;
          } catch (_) {}
        }

        // 2. Fetch rating from Kinopoisk
        try {
          final kpData = await kpService.fetchRating(
            apiKey: widget.configService.kpApiToken!,
            imdbId: imdbId,
            title: item.title,
            year: int.tryParse(item.year),
          );

          if (kpData != null) {
            final updated = item.copyWith(
              imdbId: imdbId ?? item.imdbId,
              kpRating: kpData.kpRating,
              kpVotes: kpData.kpVotes ?? item.kpVotes,
              kpId: kpData.kpId,
              imdbRating: kpData.imdbRating ?? item.imdbRating,
            );
            await widget.syncService.saveMediaItem(updated, syncToTmdb: false);
            updatedCount++;
          }
        } catch (e) {
          debugPrint('Error syncing KP rating for "${item.title}": $e');
        }

        // Delay to prevent 429 Too Many Requests
        await Future.delayed(const Duration(milliseconds: 180));
      }

      if (mounted) {
        setState(() {
          _isSyncingKp = false;
          _kpSyncProgress = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Обновлены оценки Кинопоиска для $updatedCount из $total фильмов!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncingKp = false;
          _kpSyncProgress = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления оценок: $e')),
        );
      }
    }
  }

  Future<void> _startAuthFlow() async {
    if (!widget.configService.hasApiToken) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала укажите и сохраните TMDB API токен.')),
      );
      return;
    }

    setState(() => _isConnecting = true);
    try {
      final token = await widget.apiClient.createRequestToken(
        apiToken: widget.configService.apiToken!,
      );
      final authUrl = widget.apiClient.buildAuthUrl(token);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.open_in_browser, size: 22),
                SizedBox(width: 8),
                Text('Авторизация в TMDB'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Нажмите кнопку ниже, чтобы открыть страницу TMDB в браузере.\n'
                  '2. Войдите в свой аккаунт TMDB и нажмите «Approve» (Разрешить).\n'
                  '3. Вернитесь сюда и нажмите «Я подтвердил доступ».',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                Center(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.launch, size: 16),
                    label: const Text('Открыть themoviedb.org в браузере'),
                    onPressed: () => openExternalUrl(authUrl),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() => _isConnecting = false);
                },
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _completeAuthFlow(token);
                },
                child: const Text('Я подтвердил доступ'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка инициализации авторизации: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _completeAuthFlow(String requestToken) async {
    setState(() => _isConnecting = true);
    try {
      final sessionId = await widget.apiClient.createSession(
        apiToken: widget.configService.apiToken!,
        requestToken: requestToken,
      );
      final accountInfo = await widget.apiClient.getAccountDetails(
        apiToken: widget.configService.apiToken!,
        sessionId: sessionId,
      );

      await widget.configService.setSession(
        sessionId: sessionId,
        accountInfo: accountInfo,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Аккаунт ${accountInfo.username} успешно подключен к TMDB!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось завершить авторизацию: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    try {
      final count = await widget.syncService.syncFromTmdb(
        client: widget.apiClient,
        config: widget.configService,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Синхронизировано элементов: $count!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка синхронизации: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isConnected = widget.configService.isAccountConnected;
    final account = widget.configService.accountInfo;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.movie_outlined, size: 22, color: Colors.blueAccent),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Модуль TMDB (The Movie Database)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: skin.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Поиск фильмов и сериалов, синхронизация списков и оценок',
                    style: TextStyle(fontSize: 12, color: skin.faint),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // API Token Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: skin.sidebar,
              borderRadius: BorderRadius.circular(UiRadius.card),
              border: Border.all(color: skin.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.key, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'API Read Access Token',
                      style: TextStyle(fontWeight: FontWeight.w600, color: skin.text),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Для поиска и доступа к базе данных укажите персональный токен TMDB API (или API Key v3). Получить его можно бесплатно в настройках профиля на themoviedb.org.',
                  style: TextStyle(fontSize: 12, color: skin.muted, height: 1.4),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => openExternalUrl('https://www.themoviedb.org/settings/api'),
                  child: const Text(
                    'Открыть страницу создания API ключа на TMDB ↗',
                    style: TextStyle(fontSize: 12, color: Colors.blueAccent),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tokenController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Вставьте ваш TMDB API Read Access Token (или v3 key)',
                          isDense: true,
                          filled: true,
                          fillColor: skin.hover,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(UiRadius.control),
                            borderSide: BorderSide(color: skin.outline),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _isSavingToken ? null : _saveToken,
                      child: _isSavingToken
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Сохранить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Kinopoisk API & Ratings Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: skin.sidebar,
              borderRadius: BorderRadius.circular(UiRadius.card),
              border: Border.all(color: skin.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5500),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        'КП',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Интеграция с Кинопоиском (Оценки)',
                      style: TextStyle(fontWeight: FontWeight.w600, color: skin.text),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Отображайте актуальные рейтинги и количество оценок с Кинопоиска рядом с рейтингами TMDB и IMDb в карточках и деталях фильма. Поддерживаются токены kinopoisk.dev и kinopoiskapiunofficial.tech.',
                  style: TextStyle(fontSize: 12, color: skin.muted, height: 1.4),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => openExternalUrl('https://kinopoisk.dev'),
                  child: const Text(
                    'Получить бесплатный API токен на kinopoisk.dev ↗',
                    style: TextStyle(fontSize: 12, color: Color(0xFFFF5500), fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _kpTokenController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Вставьте ваш токен kinopoisk.dev',
                          isDense: true,
                          filled: true,
                          fillColor: skin.hover,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(UiRadius.control),
                            borderSide: BorderSide(color: skin.outline),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5500),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isSavingKpToken ? null : _saveKpToken,
                      child: _isSavingKpToken
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Сохранить'),
                    ),
                  ],
                ),
                if (widget.configService.hasKpToken) ...[
                  const SizedBox(height: 16),
                  Divider(height: 1, color: skin.divider),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: _isSyncingKp
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync, size: 16, color: Color(0xFFFF5500)),
                        label: const Text(
                          'Синхронизировать оценки Кинопоиска',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF5500),
                          side: BorderSide(color: const Color(0xFFFF5500).withValues(alpha: 0.4)),
                        ),
                        onPressed: _isSyncingKp ? null : _syncKpRatings,
                      ),
                      if (_kpSyncProgress.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _kpSyncProgress,
                            style: TextStyle(fontSize: 11, color: skin.muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Account Connection Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: skin.sidebar,
              borderRadius: BorderRadius.circular(UiRadius.card),
              border: Border.all(color: skin.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_circle_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Синхронизация с аккаунтом TMDB',
                      style: TextStyle(fontWeight: FontWeight.w600, color: skin.text),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Подключите ваш личный аккаунт TMDB для двусторонней синхронизации списков «В планах» (Watchlist), «Избранное» (Favorites) и оценок.',
                  style: TextStyle(fontSize: 12, color: skin.muted, height: 1.4),
                ),
                const SizedBox(height: 16),

                if (isConnected && account != null) ...[
                  // Connected State
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                            backgroundImage: account.avatarUrl() != null ? NetworkImage(account.avatarUrl()!) : null,
                            child: account.avatarUrl() == null ? const Icon(Icons.person, size: 20) : null,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    account.username,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: skin.text,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Подключен',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'ID: ${account.id}',
                                style: TextStyle(fontSize: 11, color: skin.faint),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            icon: _isSyncing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync, size: 15),
                            label: const Text('Синхронизировать', style: TextStyle(fontSize: 11.5)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: _isSyncing ? null : _syncNow,
                          ),
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: () => widget.configService.disconnectAccount(),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Отключить', style: TextStyle(fontSize: 11.5)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ] else ...[
                  // Not Connected State
                  FilledButton.icon(
                    onPressed: _isConnecting ? null : _startAuthFlow,
                    icon: _isConnecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login, size: 18),
                    label: const Text('Подключить аккаунт TMDB'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
