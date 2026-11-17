// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get delete => 'Удалить';

  @override
  String get apply => 'Применить';

  @override
  String get retry => 'Повторить';

  @override
  String get close => 'Закрыть';

  @override
  String get copy => 'Копировать';

  @override
  String get cut => 'Вырезать';

  @override
  String get paste => 'Вставить';

  @override
  String get selectAll => 'Выделить всё';

  @override
  String get clearAll => 'Очистить всё';

  @override
  String get clear => 'Сбросить';

  @override
  String get language => 'Язык';

  @override
  String get languageSystem => 'Как в системе';

  @override
  String get languageEn => 'English';

  @override
  String get languageRu => 'Русский';

  @override
  String get themeSystem => 'Тема: Системная';

  @override
  String get themeLight => 'Тема: Светлая';

  @override
  String get themeDark => 'Тема: Тёмная';

  @override
  String get themeCycleTooltip => 'нажмите для переключения';

  @override
  String get newPage => 'Новая страница';

  @override
  String get newSubpage => 'Новая подстраница';

  @override
  String get search => 'Поиск';

  @override
  String get quickNotes => 'Заметки';

  @override
  String get pinned => 'Закрепленные';

  @override
  String get otherNotes => 'Другие заметки';

  @override
  String get quickNotePlaceholder => 'Новая заметка…';

  @override
  String get copiedToClipboard => 'Скопировано в буфер обмена';

  @override
  String get pin => 'Закрепить';

  @override
  String get unpin => 'Открепить';

  @override
  String get trash => 'Корзина';

  @override
  String get workspaceBackup => 'Резервное копирование и восстановление';

  @override
  String get duplicate => 'Дублировать';

  @override
  String get rename => 'Переименовать';

  @override
  String get moveToTrash => 'Переместить в корзину';

  @override
  String get exportMarkdown => 'Экспорт в Markdown';

  @override
  String get importNotionCsv => 'Импорт Notion CSV';

  @override
  String get untitled => 'Без названия';

  @override
  String get addIcon => 'Добавить иконку';

  @override
  String get changeIcon => 'Сменить иконку';

  @override
  String get removeIcon => 'Удалить иконку';

  @override
  String get addCover => 'Добавить обложку';

  @override
  String get changeCover => 'Сменить обложку';

  @override
  String get removeCover => 'Удалить обложку';

  @override
  String get compareVersions => 'Сравнить версии';

  @override
  String get retryTitleSave => 'Повторить сохранение заголовка';

  @override
  String get couldNotLoadPage => 'Не удалось загрузить страницу. Повторить';

  @override
  String get markdownCopied => 'Markdown скопирован в буфер обмена';

  @override
  String savedTo(String path) {
    return 'Сохранено в $path';
  }

  @override
  String get deletePage => 'Удалить страницу';

  @override
  String subpagesCount(int count) {
    return 'Вложенные страницы  $count';
  }

  @override
  String get creating => 'Создание…';

  @override
  String get failedToCreatePage =>
      'Не удалось создать страницу. Повторите попытку.';

  @override
  String get backlinks => 'Связанные упоминания';

  @override
  String get noBacklinks => 'Пока нет ссылок на эту страницу';

  @override
  String get menuCodeBlock => 'Блок кода';

  @override
  String get menuLinkToPage => 'Ссылка на страницу';

  @override
  String get menuPageCard => 'Карточка страницы';

  @override
  String get menuTableView => 'Таблица / База данных';

  @override
  String get untitledDatabase => 'Таблица без названия';

  @override
  String get untitledTable => 'Таблица без названия';

  @override
  String get loadingTable => 'Загрузка таблицы…';

  @override
  String get couldNotLoadTable => 'Не удалось загрузить таблицу. Повторить';

  @override
  String get newRow => 'Новая строка';

  @override
  String get calculate => 'Вычислить';

  @override
  String get calcSum => 'Сумма';

  @override
  String get calcAverage => 'Среднее';

  @override
  String get calcMin => 'Минимум';

  @override
  String get calcMax => 'Максимум';

  @override
  String get calcRange => 'Диапазон';

  @override
  String get calcCount => 'Количество';

  @override
  String get calcChecked => 'Отмечено';

  @override
  String get calcUnchecked => 'Не отмечено';

  @override
  String get calcPercentChecked => '% отмеченных';

  @override
  String get calcEmpty => 'Пустые';

  @override
  String get calcNotEmpty => 'Не пустые';

  @override
  String get calcUnique => 'Уникальные';

  @override
  String get calcNone => 'Нет';

  @override
  String get createTag => 'Создать тег';

  @override
  String get tagName => 'Название тега';

  @override
  String get tagColor => 'Цвет';

  @override
  String get trashTitle => 'Корзина';

  @override
  String get emptyTrash => 'Очистить корзину';

  @override
  String get emptyTrashConfirmTitle => 'Очистить корзину?';

  @override
  String get emptyTrashConfirmContent =>
      'Все страницы, базы данных, строки и блоки в корзине будут удалены навсегда. Это действие нельзя отменить.';

  @override
  String get trashEmptyState => 'Корзина пуста';

  @override
  String get restore => 'Восстановить';

  @override
  String get deletePermanently => 'Удалить навсегда';

  @override
  String get accountTitle => 'Аккаунт';

  @override
  String get yourAccount => 'Ваш аккаунт';

  @override
  String get signIn => 'Войти';

  @override
  String get createAccount => 'Создать аккаунт';

  @override
  String get signInToAccount => 'Войти в аккаунт';

  @override
  String get email => 'Email';

  @override
  String get password => 'Пароль';

  @override
  String get specifyEmail => 'Укажите email';

  @override
  String get enterPassword => 'Введите пароль';

  @override
  String get passwordMinLength => 'Не менее 8 символов';

  @override
  String get alreadyHaveAccount => 'Уже есть аккаунт? Войти';

  @override
  String get logOutAndOpenLocal => 'Выйти и открыть локальные заметки';

  @override
  String get accountGuestNotice =>
      'Используйте аккаунт. Локальные заметки останутся в гостевом пространстве.';

  @override
  String get reauthNotice =>
      'Для подключения к серверу войдите повторно. Заметки доступны локально.';

  @override
  String get unconfiguredNotice =>
      'Вход в этой сборке пока не настроен. Вы можете продолжать работать локально.';

  @override
  String get emailConfirmationNotice =>
      'Подтвердите email по ссылке из письма, затем войдите.';

  @override
  String get localNotes => 'Локальные заметки';

  @override
  String get syncReady => 'Готово к синхронизации';

  @override
  String get syncing => 'Синхронизация…';

  @override
  String get synced => 'Синхронизировано';

  @override
  String get syncOffline => 'Нет сети · сохранено локально';

  @override
  String get syncConflict => 'Есть конфликт версий';

  @override
  String get syncSetupRequired => 'Сервер синхронизации не настроен';

  @override
  String get syncAuthRequired => 'Нужно войти повторно';

  @override
  String get syncError => 'Не удалось синхронизировать';

  @override
  String get syncNow => 'Синхронизировать';

  @override
  String get resolveConflicts => 'Разрешить конфликты';

  @override
  String get backupBeforeConflict => 'Копия до разрешения конфликта';

  @override
  String waitingToSend(int count) {
    return 'Ожидают отправки: $count';
  }

  @override
  String get conflictDialogTitle => 'Конфликт версий';

  @override
  String get conflictDialogSubtitle =>
      'Обе версии сохранены. Перед выбором создаётся локальная резервная копия рабочего пространства.';

  @override
  String get onThisDevice => 'На этом устройстве';

  @override
  String get inCloud => 'В облаке';

  @override
  String get acceptCloud => 'Принять облачную';

  @override
  String get keepLocal => 'Оставить мою';

  @override
  String get noBackupsYet => 'Сохранённых копий пока нет.';

  @override
  String get backupSavedSuccess =>
      'Копия сохранена. Её можно восстановить через импорт рабочего пространства.';

  @override
  String get failedToSaveBackup => 'Не удалось сохранить файл резервной копии.';

  @override
  String get exportImportTitle => 'Резервное копирование и восстановление';

  @override
  String get tabExport => 'Экспорт';

  @override
  String get tabImport => 'Импорт';

  @override
  String get tabNotionCsv => 'Notion / CSV';

  @override
  String get tabWorkspace => 'Рабочее пространство';

  @override
  String get copyMarkdown => 'Копировать Markdown';

  @override
  String get copied => 'Скопировано!';

  @override
  String get saveMarkdownToFile => 'Сохранить в файл';

  @override
  String get createWorkspaceBackup => 'Создать резервную копию';

  @override
  String get restoreWorkspaceBackup => 'Восстановить из копии';

  @override
  String get noNoteSelected => 'Заметка не выбрана';

  @override
  String get noNoteSelectedSubtitle =>
      'Выберите заметку в боковой панели или создайте новую';

  @override
  String get newNote => 'Новая заметка';

  @override
  String get pageOptions => 'Настройки страницы';

  @override
  String get styleSection => 'Стиль';

  @override
  String get smallText => 'Мелкий шрифт';

  @override
  String get fullWidth => 'Во всю ширину';

  @override
  String get failedToSavePageSettings =>
      'Не удалось сохранить настройки страницы';

  @override
  String get noNotesYet => 'Заметок пока нет\nНажмите +, чтобы создать';

  @override
  String get moveToRoot => 'Переместить в корень';

  @override
  String get pageSection => 'Страница';

  @override
  String get copyLinkToPage => 'Копировать ссылку';

  @override
  String get subpagesSection => 'Вложенные страницы';

  @override
  String get layoutList => 'Список';

  @override
  String get layoutCards => 'Карточки';

  @override
  String get databaseUnknownTag => 'Неизвестный тег';

  @override
  String get databaseCellChangedAgain =>
      'Ячейка снова изменилась. Проверьте новое значение перед сохранением.';

  @override
  String get databaseCellConflictTitle => 'Ячейка изменена извне';

  @override
  String get databaseCellConflictBase => 'До редактирования';

  @override
  String get databaseCellConflictRemote => 'Текущее значение в базе';

  @override
  String get databaseCellConflictLocal => 'Ваш черновик';

  @override
  String get databaseCellKeepLocal => 'Сохранить мой вариант';

  @override
  String get databaseCellUseRemote => 'Использовать новое значение';

  @override
  String databaseCellConflicts(Object count) {
    return 'Конфликты ячеек: $count';
  }

  @override
  String get databaseUnsavedCellsTitle => 'Несохранённые ячейки';

  @override
  String get databaseUnsavedCellsHelp =>
      'При необходимости скопируйте текст ниже. Можно повторить запись или отменить изменения с ошибкой и использовать значения из базы данных.';

  @override
  String databaseCellSavesPending(Object count) {
    return 'Сохранение ячеек: $count';
  }

  @override
  String databaseCellSavesFailed(Object count) {
    return 'Не сохранено ячеек: $count';
  }

  @override
  String get databaseSummaryScope =>
      'По всем строкам текущей выборки, независимо от страницы';

  @override
  String get importExportSection => 'Импорт и экспорт';

  @override
  String get exportSection => 'Экспорт страницы';

  @override
  String get exportMarkdownEllipsis => 'Экспорт в Markdown...';

  @override
  String get saveMdToDownloads => 'Сохранить .md в Загрузки';

  @override
  String get importSection => 'Импорт содержимого';

  @override
  String get importNotionCsvEllipsis => 'Импорт Notion / CSV...';

  @override
  String get importMarkdownEllipsis => 'Импорт Markdown (.md)...';

  @override
  String get backupRestoreEllipsis => 'Резервные копии...';

  @override
  String get workspaceSection => 'Рабочее пространство';

  @override
  String get decideLater => 'Решить позже';

  @override
  String get useSavedVersion => 'Использовать сохранённую версию';

  @override
  String get useLocalDraft => 'Использовать локальный черновик';

  @override
  String get wipeExistingWorkspace =>
      'Удалить существующие страницы перед восстановлением';

  @override
  String get searchPlaceholder => 'Поиск страниц или введите название...';

  @override
  String get recentPages => 'НЕДАВНИЕ СТРАНИЦЫ';

  @override
  String get pagesCategory => 'СТРАНИЦЫ';

  @override
  String get noMatchingNotes => 'Заметки не найдены';

  @override
  String get createPageAction => 'Создать страницу ';

  @override
  String get navigateShortcut => 'Навигация';

  @override
  String get openShortcut => 'Открыть';

  @override
  String get closeShortcut => 'Закрыть';

  @override
  String itemsFound(int count) {
    return 'Найдено: $count';
  }

  @override
  String get pageCoverTitle => 'Обложка страницы';

  @override
  String get tabGradients => 'Градиенты';

  @override
  String get tabSolidColors => 'Цвета';

  @override
  String get selectIconTitle => 'Выбор иконки';

  @override
  String get randomIcon => 'Случайно';

  @override
  String get filterEmojiHint => 'Поиск эмодзи или свой символ...';

  @override
  String get categoryAll => 'Все';

  @override
  String currentIcon(String emoji) {
    return 'Текущая: $emoji';
  }

  @override
  String get linkToPageHint => 'Ссылка на страницу...';

  @override
  String get loading => 'Загрузка...';

  @override
  String get noPagesFound => 'Страницы не найдены';

  @override
  String get selectShortcut => 'Выбрать';

  @override
  String get cancelShortcut => 'Отмена';

  @override
  String get tabExportMd => 'Экспорт (.md)';

  @override
  String get tabImportMd => 'Импорт (.md)';

  @override
  String get tabBackupJson => 'Резервная копия (JSON)';

  @override
  String get selectPageToExport => 'Выберите страницу для экспорта в Markdown';

  @override
  String get copyToClipboard => 'Скопировать в буфер';

  @override
  String get importAsNewPage => 'Импортировать как новую страницу';

  @override
  String get loadFile => 'Загрузить файл';

  @override
  String get importAsNewDatabasePage => 'Импортировать как новую базу данных';

  @override
  String get browse => 'Обзор...';

  @override
  String get tablePreview => 'Предпросмотр таблицы';

  @override
  String get rawCsv => 'Исходный CSV';

  @override
  String get exportWorkspaceBackup => 'Экспорт копии рабочего пространства';

  @override
  String get restoreWorkspaceFromJson =>
      'Восстановление рабочего пространства из JSON';

  @override
  String get saveBackupToDownloads => 'Сохранить копию в Загрузки';

  @override
  String get restoreWorkspace => 'Восстановить рабочее пространство';

  @override
  String get databaseAddProperty => 'Добавить свойство';

  @override
  String get databaseRename => 'Переименовать базу данных';

  @override
  String get databaseSearch => 'Поиск по базе данных';

  @override
  String get databaseFilter => 'Фильтр';

  @override
  String get databaseSort => 'Сортировка';

  @override
  String get databaseOptions => 'Параметры базы данных';

  @override
  String get databaseSearchPlaceholder => 'Поиск...';

  @override
  String get databaseCloseSearch => 'Закрыть поиск';

  @override
  String databaseFilterCount(int count) {
    return 'Фильтр ($count)';
  }

  @override
  String get databaseClearSort => 'Сбросить сортировку';

  @override
  String get databaseSortAscending => 'По возрастанию ↑';

  @override
  String get databaseSortDescending => 'По убыванию ↓';

  @override
  String get databaseMoreCreationOptions => 'Другие варианты создания';

  @override
  String get columnMoveLeft => 'Переместить влево';

  @override
  String get columnMoveRight => 'Переместить вправо';

  @override
  String get columnSortAscending => 'Сортировать по возрастанию';

  @override
  String get columnSortDescending => 'Сортировать по убыванию';

  @override
  String get columnDelete => 'Удалить колонку';

  @override
  String get propTypeText => 'Текст';

  @override
  String get propTypeNumber => 'Число';

  @override
  String get propTypeSelect => 'Выбор (Теги)';

  @override
  String get propTypeMultiSelect => 'Мульти выбор';

  @override
  String get propTypeStatus => 'Статус';

  @override
  String get propTypeCheckbox => 'Чекбокс';

  @override
  String get propTypeDate => 'Дата';

  @override
  String get propTypeUrl => 'Ссылка URL';

  @override
  String get statusNotStarted => 'Не начато';

  @override
  String get statusInProgress => 'В процессе';

  @override
  String get statusDone => 'Готово';

  @override
  String get propertyNameHint => 'Название свойства';

  @override
  String get propertyDefault => 'По умолчанию';

  @override
  String get propertyNumberFormat => 'Числовой формат';

  @override
  String get propertyDecimalPlaces => 'Знаков после запятой';

  @override
  String get propertyShowAs => 'Отображать как';

  @override
  String get propertyShowAsNumber => 'Число';

  @override
  String get propertyShowAsBar => 'Шкала';

  @override
  String get propertyShowAsRing => 'Кольцо';

  @override
  String get propertyDivideBy => 'Делить на';

  @override
  String get propertyFilterFormats => 'Поиск форматов...';

  @override
  String get propertyScopeHint =>
      'Изменения применяются ко всем представлениям этого свойства.';

  @override
  String get propertyAdding => 'Добавление...';

  @override
  String get propertyError => 'Не удалось добавить свойство. Попробуйте снова.';

  @override
  String get cellClearSelection => 'Очистить выбор';

  @override
  String get cellNewTag => 'Новый тег...';

  @override
  String get cellNewStatus => 'Новый статус...';

  @override
  String get cellAddStatus => '+ Статус';

  @override
  String get cellAddMultiSelect => '+ Теги';

  @override
  String get cellUntitledPage => 'Без названия';

  @override
  String get cellTypeText => 'Введите текст...';

  @override
  String get cellCouldNotSave =>
      'Не удалось сохранить ячейку. Проверьте, что строка и колонка существуют, и повторите.';

  @override
  String get filterDialogTitle => 'Фильтр базы данных';

  @override
  String get filterActiveRules => 'Активные правила';

  @override
  String get filterAddFilter => 'Добавить фильтр';

  @override
  String get filterCheckedOnly => 'Только отмеченные';

  @override
  String get filterUncheckedOnly => 'Только неотмеченные';

  @override
  String get filterHasDate => 'С датой';

  @override
  String get filterNoDate => 'Без даты';

  @override
  String get filterHasTag => 'С тегом (Не пусто)';

  @override
  String get filterNoTag => 'Без тега (Пусто)';

  @override
  String get filterContainsUrl => 'Содержит URL / домен';

  @override
  String get durationTitle => 'Длительность';

  @override
  String get durationDays => 'Дни';

  @override
  String get durationHours => 'Часы';

  @override
  String get durationMins => 'Минуты';

  @override
  String get durationSecs => 'Секунды';

  @override
  String get rowOpenAsPage => 'Открыть как страницу';

  @override
  String get rowOpenFullPage => 'Открыть страницу полностью';

  @override
  String get rowMoveToTrash => 'Удалить строку в корзину';

  @override
  String databaseItemsCount(int count) {
    return '$count эл.';
  }

  @override
  String databaseFilteredItemsCount(int filtered, int total) {
    return '$filtered из $total';
  }

  @override
  String get databasePreviousRows => 'Предыдущие строки';

  @override
  String get databaseNextRows => 'Следующие строки';

  @override
  String databasePageRange(int from, int to, int total) {
    return '$from–$to из $total';
  }

  @override
  String get databaseAddTextAbove => 'Добавить текст выше';

  @override
  String get databaseAddTextBelow => 'Добавить текст ниже';

  @override
  String get databaseLoadError => 'Не удалось загрузить строки. Повторить';

  @override
  String get codeCopy => 'Копировать код';

  @override
  String get codePaste => 'Вставить код';

  @override
  String get codeCollapse => 'Свернуть код';

  @override
  String get codeExpand => 'Развернуть код';

  @override
  String codeShowMore(int count) {
    return 'Показать ещё ($count строк)';
  }

  @override
  String get codePlaceholder => '// Введите код здесь...';

  @override
  String codeLanguageTooltip(String language) {
    return 'Язык: $language';
  }

  @override
  String get savingStatus => 'Сохранение...';

  @override
  String get savedStatus => 'Сохранено';

  @override
  String get saveConflictDraft => 'Конфликт — черновик сохранён локально';

  @override
  String get saveError => 'Ошибка сохранения';

  @override
  String get failedToSaveSubpageLayout =>
      'Не удалось сохранить вид вложенных страниц. Повторите попытку.';

  @override
  String get failedToSaveBeforeAccountSwitch =>
      'Не удалось сохранить заметку. Повторите сохранение перед сменой аккаунта.';

  @override
  String get collapsePage => 'Свернуть подстраницы';

  @override
  String get expandPage => 'Развернуть подстраницы';

  @override
  String get urlAdd => 'Добавить URL';

  @override
  String get urlOpenInBrowser => 'Открыть в браузере';

  @override
  String get urlCopyLink => 'Скопировать ссылку';

  @override
  String get urlCopied => 'Скопировано!';

  @override
  String get urlEdit => 'Редактировать ссылку';

  @override
  String get urlClear => 'Очистить URL';

  @override
  String urlClickToOpenTooltip(String url) {
    return '$url\nНажмите, чтобы открыть • Двойной клик для редактирования';
  }

  @override
  String get numericInvalidNumber => 'Введите число, например 12.5 или 12,5.';

  @override
  String get numericInvalidDuration =>
      'Введите длительность: 1ч 30мин, 01:30:00 или секунды.';

  @override
  String get numericNonFinite => 'Число должно быть конечным.';

  @override
  String get numericFormulaUnsupported =>
      'Формулы пока не поддерживаются. Введите готовое значение.';

  @override
  String get numericSeparators =>
      'Для дробной части используйте точку или запятую, для тысяч — пробел.';

  @override
  String get numericTooLarge => 'Слишком большое значение.';

  @override
  String get numericInvalidStatus => 'Исправьте значения в ячейках';

  @override
  String get durationNegative => 'Отрицательная длительность';

  @override
  String get durationInvalidFields =>
      'Введите целые дни, часы 0–23, минуты 0–59 и секунды меньше 60.';

  @override
  String get databasePasteTitle => 'Диапазон не изменён';

  @override
  String get databasePasteMalformed =>
      'Некорректные кавычки в TSV. Скопируйте ячейки заново.';

  @override
  String get databasePasteRagged =>
      'Во всех строках должно быть одинаковое число колонок.';

  @override
  String get databasePasteTooLarge =>
      'Вставляйте не более 2000 ячеек и 2 млн символов за один раз.';

  @override
  String get databasePasteBounds =>
      'Диапазон не помещается на текущей странице таблицы. Уменьшите диапазон или выберите другую начальную ячейку.';

  @override
  String get databasePasteShape =>
      'Размер скопированного диапазона должен совпадать с выделением. Одним значением можно заполнить всё выделение.';

  @override
  String get databasePasteCheckbox =>
      'Для флажка используйте TRUE/FALSE, 1/0 или да/нет.';

  @override
  String get databasePasteDate =>
      'Введите существующую дату в формате ГГГГ-ММ-ДД (1970–2100).';

  @override
  String get databasePasteUrl => 'Используйте адрес HTTP, HTTPS или mailto.';

  @override
  String get databasePasteTag =>
      'Используйте существующие однозначные названия тегов. Несколько тегов разделяйте запятыми или укажите JSON-списком названий.';

  @override
  String get databasePasteUnsupported =>
      'Колонка не поддерживает такое значение.';

  @override
  String get databasePasteConflict =>
      'Ячейки или настройки колонок изменились. Обновите диапазон и повторите действие. Ячейки не перезаписаны.';

  @override
  String get databasePasteDrafts =>
      'Сначала завершите редактирование и сохраните или исправьте черновики в целевых ячейках.';

  @override
  String get databasePasteBusy =>
      'Дождитесь завершения текущей операции с диапазоном.';

  @override
  String get databasePasteFailed =>
      'Не удалось сохранить диапазон. Изменения не применены.';

  @override
  String get databasePasteNothingUndo => 'Нет вставки диапазона для отмены.';

  @override
  String get databasePasteNothingRedo => 'Нет вставки диапазона для повтора.';

  @override
  String get databasePasteUnchanged => 'Ячейки уже содержат эти значения.';

  @override
  String get databasePasteUndo => 'Отменить вставку';

  @override
  String get databasePasteRedo => 'Повторить вставку';

  @override
  String databasePasteSaved(int count) {
    return 'Вставлено ячеек: $count';
  }

  @override
  String databasePasteUndone(int count) {
    return 'Вставка отменена. Восстановлено ячеек: $count';
  }

  @override
  String databasePasteRedone(int count) {
    return 'Вставка повторена. Восстановлено ячеек: $count';
  }

  @override
  String databasePasteCellError(int row, String column, String message) {
    return 'Строка $row, $column: $message';
  }

  @override
  String get databaseSelectRow =>
      'Выделить строку; двойной щелчок — открыть страницу';

  @override
  String get databaseSelectColumn => 'Выделить колонку (Ctrl+Space)';

  @override
  String get databaseSelectPage => 'Выделить текущую страницу таблицы';

  @override
  String get databaseSelectionScope =>
      'Выделение на текущей загруженной странице таблицы';

  @override
  String databaseSelectionSize(int rows, int columns, int cells) {
    return '$rows × $columns · ячеек: $cells';
  }

  @override
  String get coverToPanelTop => 'Обложка до верхнего края панели';

  @override
  String get coverBelowToolbar => 'Обложка под верхней панелью';

  @override
  String get blockMoveHandle =>
      'Перетащите для перемещения · Нажмите для действий';

  @override
  String get blockMoveUp => 'Переместить выше';

  @override
  String get blockMoveDown => 'Переместить ниже';

  @override
  String get blockInsertAbove => 'Добавить блок выше';

  @override
  String get blockInsertBelow => 'Добавить блок ниже';

  @override
  String get blockCode => 'Блок кода';

  @override
  String get blockText => 'Текстовый блок';

  @override
  String get blockDatabase => 'База данных';

  @override
  String get codeTitlePlaceholder => 'Название блока';

  @override
  String get codeMoreActions => 'Действия с блоком кода';

  @override
  String get trashEmptyDescription =>
      'Удалённые страницы, базы данных и строки хранятся здесь до окончательного удаления.';

  @override
  String get trashActionFailed =>
      'Не удалось выполнить действие. Ваши данные сохранены. Попробуйте ещё раз.';

  @override
  String get trashLoadFailed => 'Не удалось загрузить корзину.';

  @override
  String get settings => 'Настройки';

  @override
  String get settingsTabGeneral => 'Основные';

  @override
  String get generalSettingsHelp => 'Внешний вид и поведение приложения';

  @override
  String get settingsAppearance => 'Оформление';

  @override
  String get settingsAutoApply => 'Изменения применяются автоматически.';

  @override
  String get theme => 'Тема';

  @override
  String get themeHelp => 'Оформление приложения';

  @override
  String get themeAuto => 'Как в системе';

  @override
  String get themeSystemShort => 'Система';

  @override
  String get themeLightShort => 'Светлая';

  @override
  String get themeDarkShort => 'Тёмная';

  @override
  String get languageHelp => 'Язык интерфейса';

  @override
  String get workspaceBackupHelp =>
      'Экспорт и восстановление рабочего пространства в JSON';

  @override
  String get openAction => 'Открыть…';

  @override
  String get about => 'О приложении';

  @override
  String appVersion(String version) {
    return 'Версия $version';
  }

  @override
  String get sync => 'Синхронизация';

  @override
  String get syncHelp =>
      'Заметки хранятся на этом компьютере. Сервер нужен, чтобы они появились на других устройствах.';

  @override
  String get syncTabSignIn => 'Вход';

  @override
  String get syncTabSignUp => 'Регистрация';

  @override
  String syncSignedInAs(String email) {
    return 'Вы вошли как $email';
  }

  @override
  String get syncSignOut => 'Выйти';

  @override
  String get menuCallout => 'Выноска';

  @override
  String get menuToggle => 'Сворачиваемый список';

  @override
  String get calloutPlaceholder => 'Текст выноски...';

  @override
  String get togglePlaceholder => 'Раздел';

  @override
  String get toggleEmptyHint => 'Пустой раздел. Нажмите, чтобы добавить текст';

  @override
  String get blockCallout => 'Выноска';

  @override
  String get blockToggle => 'Спойлер';

  @override
  String get blockImage => 'Изображение';

  @override
  String get dropImageHint => 'Отпустите изображение для вставки';

  @override
  String get turnInto => 'Превратить в…';

  @override
  String get turnIntoText => 'Текст';

  @override
  String get turnIntoH1 => 'Заголовок 1';

  @override
  String get turnIntoH2 => 'Заголовок 2';

  @override
  String get turnIntoH3 => 'Заголовок 3';

  @override
  String get turnIntoBulletList => 'Список с маркерами';

  @override
  String get turnIntoNumberedList => 'Нумерованный список';

  @override
  String get turnIntoTodoList => 'Список задач';

  @override
  String get turnIntoQuote => 'Цитата';

  @override
  String get turnIntoCode => 'Блок кода';

  @override
  String get turnIntoCallout => 'Выноска';

  @override
  String get turnIntoToggle => 'Сворачиваемый список';

  @override
  String get copyBlockText => 'Копировать текст';

  @override
  String get back => 'Назад';

  @override
  String get toggleSidebar => 'Боковое меню';

  @override
  String get hideSidebar => 'Скрыть боковое меню';

  @override
  String get showSidebar => 'Показать боковое меню';

  @override
  String get navBack => 'Назад';

  @override
  String get navForward => 'Вперёд';
}
