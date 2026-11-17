// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get apply => 'Apply';

  @override
  String get retry => 'Retry';

  @override
  String get close => 'Close';

  @override
  String get copy => 'Copy';

  @override
  String get cut => 'Cut';

  @override
  String get paste => 'Paste';

  @override
  String get selectAll => 'Select all';

  @override
  String get clearAll => 'Clear all';

  @override
  String get clear => 'Clear';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEn => 'English';

  @override
  String get languageRu => 'Русский';

  @override
  String get themeSystem => 'Theme: System';

  @override
  String get themeLight => 'Theme: Light';

  @override
  String get themeDark => 'Theme: Dark';

  @override
  String get themeCycleTooltip => 'click to cycle';

  @override
  String get newPage => 'New page';

  @override
  String get newSubpage => 'New subpage';

  @override
  String get search => 'Search';

  @override
  String get quickNotes => 'Notes';

  @override
  String get pinned => 'Pinned';

  @override
  String get otherNotes => 'Other notes';

  @override
  String get quickNotePlaceholder => 'New note...';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get pin => 'Pin';

  @override
  String get unpin => 'Unpin';

  @override
  String get trash => 'Trash';

  @override
  String get workspaceBackup => 'Workspace Backup & Restore';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get rename => 'Rename';

  @override
  String get moveToTrash => 'Move to trash';

  @override
  String get exportMarkdown => 'Export Markdown';

  @override
  String get importNotionCsv => 'Import Notion CSV';

  @override
  String get untitled => 'Untitled';

  @override
  String get addIcon => 'Add icon';

  @override
  String get changeIcon => 'Change icon';

  @override
  String get removeIcon => 'Remove icon';

  @override
  String get addCover => 'Add cover';

  @override
  String get changeCover => 'Change cover';

  @override
  String get removeCover => 'Remove cover';

  @override
  String get compareVersions => 'Compare versions';

  @override
  String get retryTitleSave => 'Retry title save';

  @override
  String get couldNotLoadPage => 'Could not load this page. Retry';

  @override
  String get markdownCopied => 'Markdown copied to clipboard';

  @override
  String savedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String get deletePage => 'Delete page';

  @override
  String subpagesCount(int count) {
    return 'Subpages  $count';
  }

  @override
  String get creating => 'Creating…';

  @override
  String get failedToCreatePage => 'Could not create page. Please try again.';

  @override
  String get backlinks => 'Linked mentions';

  @override
  String get noBacklinks => 'No backlinks to this page yet';

  @override
  String get menuCodeBlock => 'Code block';

  @override
  String get menuLinkToPage => 'Link to page';

  @override
  String get menuPageCard => 'Page card';

  @override
  String get menuTableView => 'Table view / Database';

  @override
  String get untitledDatabase => 'Untitled Database';

  @override
  String get untitledTable => 'Untitled Table';

  @override
  String get loadingTable => 'Loading table…';

  @override
  String get couldNotLoadTable => 'Could not load table. Retry';

  @override
  String get newRow => 'New';

  @override
  String get calculate => 'Calculate';

  @override
  String get calcSum => 'Sum';

  @override
  String get calcAverage => 'Average';

  @override
  String get calcMin => 'Min';

  @override
  String get calcMax => 'Max';

  @override
  String get calcRange => 'Range';

  @override
  String get calcCount => 'Count';

  @override
  String get calcChecked => 'Checked';

  @override
  String get calcUnchecked => 'Unchecked';

  @override
  String get calcPercentChecked => '% Checked';

  @override
  String get calcEmpty => 'Empty';

  @override
  String get calcNotEmpty => 'Not empty';

  @override
  String get calcUnique => 'Unique';

  @override
  String get calcNone => 'None';

  @override
  String get createTag => 'Create Tag';

  @override
  String get tagName => 'Tag name';

  @override
  String get tagColor => 'Color';

  @override
  String get trashTitle => 'Trash';

  @override
  String get emptyTrash => 'Empty Trash';

  @override
  String get emptyTrashConfirmTitle => 'Empty Trash?';

  @override
  String get emptyTrashConfirmContent =>
      'All pages, databases, rows and blocks in the trash will be permanently erased. This action cannot be undone.';

  @override
  String get trashEmptyState => 'Trash is empty';

  @override
  String get restore => 'Restore';

  @override
  String get deletePermanently => 'Delete permanently';

  @override
  String get accountTitle => 'Account';

  @override
  String get yourAccount => 'Your Account';

  @override
  String get signIn => 'Sign In';

  @override
  String get createAccount => 'Create account';

  @override
  String get signInToAccount => 'Sign in to account';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get specifyEmail => 'Specify email';

  @override
  String get enterPassword => 'Enter password';

  @override
  String get passwordMinLength => 'At least 8 characters';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign In';

  @override
  String get logOutAndOpenLocal => 'Sign out and open local notes';

  @override
  String get accountGuestNotice =>
      'Use your account. Local notes will stay in guest space.';

  @override
  String get reauthNotice =>
      'To connect to server, please sign in again. Notes are available locally.';

  @override
  String get unconfiguredNotice =>
      'Sign in is not configured in this build. You can continue working locally.';

  @override
  String get emailConfirmationNotice =>
      'Confirm your email using the link in the message, then sign in.';

  @override
  String get localNotes => 'Local notes';

  @override
  String get syncReady => 'Ready to sync';

  @override
  String get syncing => 'Syncing…';

  @override
  String get synced => 'Synced';

  @override
  String get syncOffline => 'No network · saved locally';

  @override
  String get syncConflict => 'Version conflict';

  @override
  String get syncSetupRequired => 'Sync server is not configured';

  @override
  String get syncAuthRequired => 'Sign in required';

  @override
  String get syncError => 'Could not sync';

  @override
  String get syncNow => 'Sync now';

  @override
  String get resolveConflicts => 'Resolve conflicts';

  @override
  String get backupBeforeConflict => 'Backup before resolving conflict';

  @override
  String waitingToSend(int count) {
    return 'Pending changes: $count';
  }

  @override
  String get conflictDialogTitle => 'Version Conflict';

  @override
  String get conflictDialogSubtitle =>
      'Both versions are saved. A local workspace backup is created before choosing.';

  @override
  String get onThisDevice => 'On this device';

  @override
  String get inCloud => 'In the cloud';

  @override
  String get acceptCloud => 'Accept cloud';

  @override
  String get keepLocal => 'Keep mine';

  @override
  String get noBackupsYet => 'No saved backups yet.';

  @override
  String get backupSavedSuccess =>
      'Backup saved. It can be restored via workspace import.';

  @override
  String get failedToSaveBackup => 'Could not save backup file.';

  @override
  String get exportImportTitle => 'Backup & Restore';

  @override
  String get tabExport => 'Export';

  @override
  String get tabImport => 'Import';

  @override
  String get tabNotionCsv => 'Notion / CSV';

  @override
  String get tabWorkspace => 'Workspace';

  @override
  String get copyMarkdown => 'Copy Markdown';

  @override
  String get copied => 'Copied!';

  @override
  String get saveMarkdownToFile => 'Save to File';

  @override
  String get createWorkspaceBackup => 'Create Backup';

  @override
  String get restoreWorkspaceBackup => 'Restore Backup';

  @override
  String get noNoteSelected => 'No Note Selected';

  @override
  String get noNoteSelectedSubtitle =>
      'Select a note from the sidebar or create a new one';

  @override
  String get newNote => 'New Note';

  @override
  String get pageOptions => 'Page options';

  @override
  String get styleSection => 'Style';

  @override
  String get smallText => 'Small text';

  @override
  String get fullWidth => 'Full width';

  @override
  String get failedToSavePageSettings => 'Failed to save page settings';

  @override
  String get noNotesYet => 'No notes yet\nClick + to create';

  @override
  String get moveToRoot => 'Move to Root';

  @override
  String get pageSection => 'Page';

  @override
  String get copyLinkToPage => 'Copy link to page';

  @override
  String get subpagesSection => 'Subpages';

  @override
  String get layoutList => 'List';

  @override
  String get layoutCards => 'Cards';

  @override
  String get databaseUnknownTag => 'Unknown tag';

  @override
  String get databaseCellChangedAgain =>
      'This cell changed again. Review the new value before saving.';

  @override
  String get databaseCellConflictTitle => 'Cell changed elsewhere';

  @override
  String get databaseCellConflictBase => 'Before editing';

  @override
  String get databaseCellConflictRemote => 'Current database value';

  @override
  String get databaseCellConflictLocal => 'Your draft';

  @override
  String get databaseCellKeepLocal => 'Save my version';

  @override
  String get databaseCellUseRemote => 'Use the new value';

  @override
  String databaseCellConflicts(Object count) {
    return 'Cell conflicts: $count';
  }

  @override
  String get databaseUnsavedCellsTitle => 'Unsaved cells';

  @override
  String get databaseUnsavedCellsHelp =>
      'Copy the draft text below if needed. Retry saving, or discard failed edits and use the values stored in the database.';

  @override
  String databaseCellSavesPending(Object count) {
    return 'Saving cells: $count';
  }

  @override
  String databaseCellSavesFailed(Object count) {
    return 'Unsaved cells: $count';
  }

  @override
  String get databaseSummaryScope =>
      'All rows in the current selection, across every page';

  @override
  String get importExportSection => 'Import and export';

  @override
  String get exportSection => 'Export Page';

  @override
  String get exportMarkdownEllipsis => 'Export Markdown...';

  @override
  String get saveMdToDownloads => 'Save .md to Downloads';

  @override
  String get importSection => 'Import Content';

  @override
  String get importNotionCsvEllipsis => 'Import Notion / CSV...';

  @override
  String get importMarkdownEllipsis => 'Import Markdown (.md)...';

  @override
  String get backupRestoreEllipsis => 'Backup & Restore...';

  @override
  String get workspaceSection => 'Workspace';

  @override
  String get decideLater => 'Decide later';

  @override
  String get useSavedVersion => 'Use saved version';

  @override
  String get useLocalDraft => 'Use local draft';

  @override
  String get wipeExistingWorkspace => 'Erase existing pages before restore';

  @override
  String get searchPlaceholder => 'Search pages or type to create...';

  @override
  String get recentPages => 'RECENT PAGES';

  @override
  String get pagesCategory => 'PAGES';

  @override
  String get noMatchingNotes => 'No matching notes';

  @override
  String get createPageAction => 'Create page ';

  @override
  String get navigateShortcut => 'Navigate';

  @override
  String get openShortcut => 'Open';

  @override
  String get closeShortcut => 'Close';

  @override
  String itemsFound(int count) {
    return '$count found';
  }

  @override
  String get pageCoverTitle => 'Page Cover';

  @override
  String get tabGradients => 'Gradients';

  @override
  String get tabSolidColors => 'Solid Colors';

  @override
  String get selectIconTitle => 'Select Icon';

  @override
  String get randomIcon => 'Random';

  @override
  String get filterEmojiHint => 'Filter emoji or paste custom...';

  @override
  String get categoryAll => 'All';

  @override
  String currentIcon(String emoji) {
    return 'Current: $emoji';
  }

  @override
  String get linkToPageHint => 'Link to page...';

  @override
  String get loading => 'Loading...';

  @override
  String get noPagesFound => 'No pages found';

  @override
  String get selectShortcut => 'Select';

  @override
  String get cancelShortcut => 'Cancel';

  @override
  String get tabExportMd => 'Export (.md)';

  @override
  String get tabImportMd => 'Import (.md)';

  @override
  String get tabBackupJson => 'Backup (JSON)';

  @override
  String get selectPageToExport => 'Select a page to export as Markdown';

  @override
  String get copyToClipboard => 'Copy to Clipboard';

  @override
  String get importAsNewPage => 'Import as New Page';

  @override
  String get loadFile => 'Load File';

  @override
  String get importAsNewDatabasePage => 'Import as New Database Page';

  @override
  String get browse => 'Browse...';

  @override
  String get tablePreview => 'Table Preview';

  @override
  String get rawCsv => 'Raw CSV';

  @override
  String get exportWorkspaceBackup => 'Export Workspace Backup';

  @override
  String get restoreWorkspaceFromJson => 'Restore Workspace from JSON';

  @override
  String get saveBackupToDownloads => 'Save Backup to Downloads';

  @override
  String get restoreWorkspace => 'Restore Workspace';

  @override
  String get databaseAddProperty => 'Add property';

  @override
  String get databaseRename => 'Rename database';

  @override
  String get databaseSearch => 'Search database';

  @override
  String get databaseFilter => 'Filter';

  @override
  String get databaseSort => 'Sort';

  @override
  String get databaseOptions => 'Database options';

  @override
  String get databaseSearchPlaceholder => 'Search...';

  @override
  String get databaseCloseSearch => 'Close search';

  @override
  String databaseFilterCount(int count) {
    return 'Filter ($count)';
  }

  @override
  String get databaseClearSort => 'Clear sort';

  @override
  String get databaseSortAscending => 'Ascending ↑';

  @override
  String get databaseSortDescending => 'Descending ↓';

  @override
  String get databaseMoreCreationOptions => 'More creation options';

  @override
  String get columnMoveLeft => 'Move left';

  @override
  String get columnMoveRight => 'Move right';

  @override
  String get columnSortAscending => 'Sort ascending';

  @override
  String get columnSortDescending => 'Sort descending';

  @override
  String get columnDelete => 'Delete column';

  @override
  String get propTypeText => 'Text';

  @override
  String get propTypeNumber => 'Number';

  @override
  String get propTypeSelect => 'Select (Tags)';

  @override
  String get propTypeMultiSelect => 'Multi-select';

  @override
  String get propTypeStatus => 'Status';

  @override
  String get propTypeCheckbox => 'Checkbox';

  @override
  String get propTypeDate => 'Date';

  @override
  String get propTypeUrl => 'URL Link';

  @override
  String get statusNotStarted => 'Not started';

  @override
  String get statusInProgress => 'In progress';

  @override
  String get statusDone => 'Done';

  @override
  String get propertyNameHint => 'Property name';

  @override
  String get propertyDefault => 'Default';

  @override
  String get propertyNumberFormat => 'Number format';

  @override
  String get propertyDecimalPlaces => 'Decimal places';

  @override
  String get propertyShowAs => 'Show as';

  @override
  String get propertyShowAsNumber => 'Number';

  @override
  String get propertyShowAsBar => 'Bar';

  @override
  String get propertyShowAsRing => 'Ring';

  @override
  String get propertyDivideBy => 'Divide by';

  @override
  String get propertyFilterFormats => 'Filter formats...';

  @override
  String get propertyScopeHint =>
      'Changes apply to all views showing this property.';

  @override
  String get propertyAdding => 'Adding...';

  @override
  String get propertyError => 'Could not add property. Try again.';

  @override
  String get cellClearSelection => 'Clear selection';

  @override
  String get cellNewTag => 'New tag...';

  @override
  String get cellNewStatus => 'New status...';

  @override
  String get cellAddStatus => '+ Status';

  @override
  String get cellAddMultiSelect => '+ Tags';

  @override
  String get cellUntitledPage => 'Untitled page';

  @override
  String get cellTypeText => 'Type text...';

  @override
  String get cellCouldNotSave =>
      'Could not save this cell. Check that the row and column still exist, then try again.';

  @override
  String get filterDialogTitle => 'Filter Database';

  @override
  String get filterActiveRules => 'Active Rules';

  @override
  String get filterAddFilter => 'Add Filter';

  @override
  String get filterCheckedOnly => 'Checked only';

  @override
  String get filterUncheckedOnly => 'Unchecked only';

  @override
  String get filterHasDate => 'Has date';

  @override
  String get filterNoDate => 'No date';

  @override
  String get filterHasTag => 'Has tag (Not empty)';

  @override
  String get filterNoTag => 'No tag (Empty)';

  @override
  String get filterContainsUrl => 'Contains URL / domain';

  @override
  String get durationTitle => 'Duration';

  @override
  String get durationDays => 'Days';

  @override
  String get durationHours => 'Hours';

  @override
  String get durationMins => 'Mins';

  @override
  String get durationSecs => 'Secs';

  @override
  String get rowOpenAsPage => 'Open as page';

  @override
  String get rowOpenFullPage => 'Open full page';

  @override
  String get rowMoveToTrash => 'Move row to trash';

  @override
  String databaseItemsCount(int count) {
    return '$count items';
  }

  @override
  String databaseFilteredItemsCount(int filtered, int total) {
    return '$filtered of $total';
  }

  @override
  String get databasePreviousRows => 'Previous rows';

  @override
  String get databaseNextRows => 'Next rows';

  @override
  String databasePageRange(int from, int to, int total) {
    return '$from–$to of $total';
  }

  @override
  String get databaseAddTextAbove => 'Add text above';

  @override
  String get databaseAddTextBelow => 'Add text below';

  @override
  String get databaseLoadError => 'Could not load rows. Retry';

  @override
  String get codeCopy => 'Copy code';

  @override
  String get codePaste => 'Paste code';

  @override
  String get codeCollapse => 'Collapse code';

  @override
  String get codeExpand => 'Expand code';

  @override
  String codeShowMore(int count) {
    return 'Show more ($count lines)';
  }

  @override
  String get codePlaceholder => '// Type code here...';

  @override
  String codeLanguageTooltip(String language) {
    return 'Language: $language';
  }

  @override
  String get savingStatus => 'Saving...';

  @override
  String get savedStatus => 'Saved';

  @override
  String get saveConflictDraft => 'Conflict — draft kept locally';

  @override
  String get saveError => 'Save error';

  @override
  String get failedToSaveSubpageLayout =>
      'Could not save subpages layout. Please try again.';

  @override
  String get failedToSaveBeforeAccountSwitch =>
      'Could not save note. Please retry saving before switching accounts.';

  @override
  String get collapsePage => 'Collapse page';

  @override
  String get expandPage => 'Expand page';

  @override
  String get urlAdd => 'Add URL';

  @override
  String get urlOpenInBrowser => 'Open in browser';

  @override
  String get urlCopyLink => 'Copy link';

  @override
  String get urlCopied => 'Copied!';

  @override
  String get urlEdit => 'Edit URL';

  @override
  String get urlClear => 'Clear URL';

  @override
  String urlClickToOpenTooltip(String url) {
    return '$url\nClick to open • Double-click to edit';
  }

  @override
  String get numericInvalidNumber =>
      'Enter a number, for example 12.5 or 12,5.';

  @override
  String get numericInvalidDuration =>
      'Enter a duration: 1h 30m, 01:30:00, or seconds.';

  @override
  String get numericNonFinite => 'The number must be finite.';

  @override
  String get numericFormulaUnsupported =>
      'Formulas are not supported. Enter the calculated value.';

  @override
  String get numericSeparators =>
      'Use a point or comma for decimals and spaces for thousands.';

  @override
  String get numericTooLarge => 'The value is too large.';

  @override
  String get numericInvalidStatus => 'Correct invalid cell values';

  @override
  String get durationNegative => 'Negative duration';

  @override
  String get durationInvalidFields =>
      'Use whole days, hours 0–23, minutes 0–59, and seconds below 60.';

  @override
  String get databasePasteTitle => 'Range not changed';

  @override
  String get databasePasteMalformed =>
      'Invalid TSV quoting. Copy the cells again.';

  @override
  String get databasePasteRagged =>
      'Every row must have the same number of columns.';

  @override
  String get databasePasteTooLarge =>
      'Paste up to 2,000 cells and 2 million characters at a time.';

  @override
  String get databasePasteBounds =>
      'The range does not fit on this table page. Choose a smaller range or another starting cell.';

  @override
  String get databasePasteShape =>
      'The copied range must match the selection size. One value can fill the entire selection.';

  @override
  String get databasePasteCheckbox =>
      'Use TRUE/FALSE, 1/0, or yes/no for a checkbox.';

  @override
  String get databasePasteDate =>
      'Use a valid date in YYYY-MM-DD format (1970–2100).';

  @override
  String get databasePasteUrl => 'Use an HTTP, HTTPS, or mailto address.';

  @override
  String get databasePasteTag =>
      'Use existing, unambiguous tag names. Separate multiple tags with commas or use a JSON list of names.';

  @override
  String get databasePasteUnsupported =>
      'This value is not supported by the column.';

  @override
  String get databasePasteConflict =>
      'Cells or column settings have changed. Refresh the range and try again. No cells were overwritten.';

  @override
  String get databasePasteDrafts =>
      'Finish editing and resolve unsaved values in the target cells first.';

  @override
  String get databasePasteBusy =>
      'Wait for the current range operation to finish.';

  @override
  String get databasePasteFailed =>
      'The range could not be saved. No changes were applied.';

  @override
  String get databasePasteNothingUndo => 'No range paste to undo.';

  @override
  String get databasePasteNothingRedo => 'No range paste to redo.';

  @override
  String get databasePasteUnchanged =>
      'The cells already contain these values.';

  @override
  String get databasePasteUndo => 'Undo paste';

  @override
  String get databasePasteRedo => 'Redo paste';

  @override
  String databasePasteSaved(int count) {
    return 'Pasted cells: $count';
  }

  @override
  String databasePasteUndone(int count) {
    return 'Paste undone. Cells restored: $count';
  }

  @override
  String databasePasteRedone(int count) {
    return 'Paste redone. Cells restored: $count';
  }

  @override
  String databasePasteCellError(int row, String column, String message) {
    return 'Row $row, $column: $message';
  }

  @override
  String get databaseSelectRow => 'Select row; double-click to open page';

  @override
  String get databaseSelectColumn => 'Select column (Ctrl+Space)';

  @override
  String get databaseSelectPage => 'Select this table page';

  @override
  String get databaseSelectionScope =>
      'Selection on the current loaded table page';

  @override
  String databaseSelectionSize(int rows, int columns, int cells) {
    return '$rows × $columns · cells: $cells';
  }

  @override
  String get coverToPanelTop => 'Extend cover to panel top';

  @override
  String get coverBelowToolbar => 'Place cover below toolbar';

  @override
  String get blockMoveHandle => 'Drag to move · Click for actions';

  @override
  String get blockMoveUp => 'Move above';

  @override
  String get blockMoveDown => 'Move below';

  @override
  String get blockInsertAbove => 'Insert block above';

  @override
  String get blockInsertBelow => 'Insert block below';

  @override
  String get blockCode => 'Code block';

  @override
  String get blockText => 'Text block';

  @override
  String get blockDatabase => 'Database';

  @override
  String get codeTitlePlaceholder => 'Block name';

  @override
  String get codeMoreActions => 'Code block actions';

  @override
  String get trashEmptyDescription =>
      'Deleted pages, databases and rows appear here until permanently deleted.';

  @override
  String get trashActionFailed =>
      'Could not complete this trash action. Your data has been kept. Try again.';

  @override
  String get trashLoadFailed => 'Could not load the trash.';

  @override
  String get settings => 'Settings';

  @override
  String get settingsTabGeneral => 'General';

  @override
  String get generalSettingsHelp => 'Appearance and app behavior';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAutoApply => 'Changes apply automatically.';

  @override
  String get theme => 'Theme';

  @override
  String get themeHelp => 'Application appearance';

  @override
  String get themeAuto => 'System default';

  @override
  String get themeSystemShort => 'System';

  @override
  String get themeLightShort => 'Light';

  @override
  String get themeDarkShort => 'Dark';

  @override
  String get languageHelp => 'Interface language';

  @override
  String get workspaceBackupHelp => 'Export and restore workspace in JSON';

  @override
  String get openAction => 'Open…';

  @override
  String get about => 'About';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String get sync => 'Sync';

  @override
  String get syncHelp =>
      'Notes are stored on this computer. A server is only needed to keep them in sync across your other devices.';

  @override
  String get syncTabSignIn => 'Sign In';

  @override
  String get syncTabSignUp => 'Sign Up';

  @override
  String syncSignedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get syncSignOut => 'Sign out';

  @override
  String get menuCallout => 'Callout';

  @override
  String get menuToggle => 'Toggle list';

  @override
  String get calloutPlaceholder => 'Write a callout...';

  @override
  String get togglePlaceholder => 'Toggle';

  @override
  String get toggleEmptyHint => 'Empty toggle. Click to add content';

  @override
  String get blockCallout => 'Callout';

  @override
  String get blockToggle => 'Toggle';

  @override
  String get blockImage => 'Image';

  @override
  String get dropImageHint => 'Drop image to insert';

  @override
  String get turnInto => 'Turn into';

  @override
  String get turnIntoText => 'Text';

  @override
  String get turnIntoH1 => 'Heading 1';

  @override
  String get turnIntoH2 => 'Heading 2';

  @override
  String get turnIntoH3 => 'Heading 3';

  @override
  String get turnIntoBulletList => 'Bulleted list';

  @override
  String get turnIntoNumberedList => 'Numbered list';

  @override
  String get turnIntoTodoList => 'To-do list';

  @override
  String get turnIntoQuote => 'Quote';

  @override
  String get turnIntoCode => 'Code block';

  @override
  String get turnIntoCallout => 'Callout';

  @override
  String get turnIntoToggle => 'Toggle list';

  @override
  String get copyBlockText => 'Copy text';

  @override
  String get back => 'Back';

  @override
  String get toggleSidebar => 'Sidebar';

  @override
  String get hideSidebar => 'Hide sidebar';

  @override
  String get showSidebar => 'Show sidebar';

  @override
  String get navBack => 'Back';

  @override
  String get navForward => 'Forward';
}
