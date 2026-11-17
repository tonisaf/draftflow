import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @cut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get cut;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @languageRu.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageRu;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Theme: System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Theme: Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Theme: Dark'**
  String get themeDark;

  /// No description provided for @themeCycleTooltip.
  ///
  /// In en, this message translates to:
  /// **'click to cycle'**
  String get themeCycleTooltip;

  /// No description provided for @newPage.
  ///
  /// In en, this message translates to:
  /// **'New page'**
  String get newPage;

  /// No description provided for @newSubpage.
  ///
  /// In en, this message translates to:
  /// **'New subpage'**
  String get newSubpage;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Label for the Notes panel
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get quickNotes;

  /// Section header for pinned notes
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinned;

  /// Section header for other notes
  ///
  /// In en, this message translates to:
  /// **'Other notes'**
  String get otherNotes;

  /// Placeholder for quick note creation bar
  ///
  /// In en, this message translates to:
  /// **'New note...'**
  String get quickNotePlaceholder;

  /// Notification message when text is copied
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// Action to pin a note
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// Action to unpin a note
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @trash.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get trash;

  /// No description provided for @workspaceBackup.
  ///
  /// In en, this message translates to:
  /// **'Workspace Backup & Restore'**
  String get workspaceBackup;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @moveToTrash.
  ///
  /// In en, this message translates to:
  /// **'Move to trash'**
  String get moveToTrash;

  /// No description provided for @exportMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Export Markdown'**
  String get exportMarkdown;

  /// No description provided for @importNotionCsv.
  ///
  /// In en, this message translates to:
  /// **'Import Notion CSV'**
  String get importNotionCsv;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @addIcon.
  ///
  /// In en, this message translates to:
  /// **'Add icon'**
  String get addIcon;

  /// No description provided for @changeIcon.
  ///
  /// In en, this message translates to:
  /// **'Change icon'**
  String get changeIcon;

  /// No description provided for @removeIcon.
  ///
  /// In en, this message translates to:
  /// **'Remove icon'**
  String get removeIcon;

  /// No description provided for @addCover.
  ///
  /// In en, this message translates to:
  /// **'Add cover'**
  String get addCover;

  /// No description provided for @changeCover.
  ///
  /// In en, this message translates to:
  /// **'Change cover'**
  String get changeCover;

  /// No description provided for @removeCover.
  ///
  /// In en, this message translates to:
  /// **'Remove cover'**
  String get removeCover;

  /// No description provided for @compareVersions.
  ///
  /// In en, this message translates to:
  /// **'Compare versions'**
  String get compareVersions;

  /// No description provided for @retryTitleSave.
  ///
  /// In en, this message translates to:
  /// **'Retry title save'**
  String get retryTitleSave;

  /// No description provided for @couldNotLoadPage.
  ///
  /// In en, this message translates to:
  /// **'Could not load this page. Retry'**
  String get couldNotLoadPage;

  /// No description provided for @markdownCopied.
  ///
  /// In en, this message translates to:
  /// **'Markdown copied to clipboard'**
  String get markdownCopied;

  /// No description provided for @savedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String savedTo(String path);

  /// No description provided for @deletePage.
  ///
  /// In en, this message translates to:
  /// **'Delete page'**
  String get deletePage;

  /// No description provided for @subpagesCount.
  ///
  /// In en, this message translates to:
  /// **'Subpages  {count}'**
  String subpagesCount(int count);

  /// No description provided for @creating.
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get creating;

  /// No description provided for @failedToCreatePage.
  ///
  /// In en, this message translates to:
  /// **'Could not create page. Please try again.'**
  String get failedToCreatePage;

  /// No description provided for @backlinks.
  ///
  /// In en, this message translates to:
  /// **'Linked mentions'**
  String get backlinks;

  /// No description provided for @noBacklinks.
  ///
  /// In en, this message translates to:
  /// **'No backlinks to this page yet'**
  String get noBacklinks;

  /// No description provided for @menuCodeBlock.
  ///
  /// In en, this message translates to:
  /// **'Code block'**
  String get menuCodeBlock;

  /// No description provided for @menuLinkToPage.
  ///
  /// In en, this message translates to:
  /// **'Link to page'**
  String get menuLinkToPage;

  /// No description provided for @menuPageCard.
  ///
  /// In en, this message translates to:
  /// **'Page card'**
  String get menuPageCard;

  /// No description provided for @menuTableView.
  ///
  /// In en, this message translates to:
  /// **'Table view / Database'**
  String get menuTableView;

  /// No description provided for @untitledDatabase.
  ///
  /// In en, this message translates to:
  /// **'Untitled Database'**
  String get untitledDatabase;

  /// No description provided for @untitledTable.
  ///
  /// In en, this message translates to:
  /// **'Untitled Table'**
  String get untitledTable;

  /// No description provided for @loadingTable.
  ///
  /// In en, this message translates to:
  /// **'Loading table…'**
  String get loadingTable;

  /// No description provided for @couldNotLoadTable.
  ///
  /// In en, this message translates to:
  /// **'Could not load table. Retry'**
  String get couldNotLoadTable;

  /// No description provided for @newRow.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newRow;

  /// No description provided for @calculate.
  ///
  /// In en, this message translates to:
  /// **'Calculate'**
  String get calculate;

  /// No description provided for @calcSum.
  ///
  /// In en, this message translates to:
  /// **'Sum'**
  String get calcSum;

  /// No description provided for @calcAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get calcAverage;

  /// No description provided for @calcMin.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get calcMin;

  /// No description provided for @calcMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get calcMax;

  /// No description provided for @calcRange.
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get calcRange;

  /// No description provided for @calcCount.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get calcCount;

  /// No description provided for @calcChecked.
  ///
  /// In en, this message translates to:
  /// **'Checked'**
  String get calcChecked;

  /// No description provided for @calcUnchecked.
  ///
  /// In en, this message translates to:
  /// **'Unchecked'**
  String get calcUnchecked;

  /// No description provided for @calcPercentChecked.
  ///
  /// In en, this message translates to:
  /// **'% Checked'**
  String get calcPercentChecked;

  /// No description provided for @calcEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get calcEmpty;

  /// No description provided for @calcNotEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not empty'**
  String get calcNotEmpty;

  /// No description provided for @calcUnique.
  ///
  /// In en, this message translates to:
  /// **'Unique'**
  String get calcUnique;

  /// No description provided for @calcNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get calcNone;

  /// No description provided for @createTag.
  ///
  /// In en, this message translates to:
  /// **'Create Tag'**
  String get createTag;

  /// No description provided for @tagName.
  ///
  /// In en, this message translates to:
  /// **'Tag name'**
  String get tagName;

  /// No description provided for @tagColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get tagColor;

  /// No description provided for @trashTitle.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get trashTitle;

  /// No description provided for @emptyTrash.
  ///
  /// In en, this message translates to:
  /// **'Empty Trash'**
  String get emptyTrash;

  /// No description provided for @emptyTrashConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Empty Trash?'**
  String get emptyTrashConfirmTitle;

  /// No description provided for @emptyTrashConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'All pages, databases, rows and blocks in the trash will be permanently erased. This action cannot be undone.'**
  String get emptyTrashConfirmContent;

  /// No description provided for @trashEmptyState.
  ///
  /// In en, this message translates to:
  /// **'Trash is empty'**
  String get trashEmptyState;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @deletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get deletePermanently;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @yourAccount.
  ///
  /// In en, this message translates to:
  /// **'Your Account'**
  String get yourAccount;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @signInToAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to account'**
  String get signInToAccount;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @specifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Specify email'**
  String get specifyEmail;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get enterPassword;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordMinLength;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign In'**
  String get alreadyHaveAccount;

  /// No description provided for @logOutAndOpenLocal.
  ///
  /// In en, this message translates to:
  /// **'Sign out and open local notes'**
  String get logOutAndOpenLocal;

  /// No description provided for @accountGuestNotice.
  ///
  /// In en, this message translates to:
  /// **'Use your account. Local notes will stay in guest space.'**
  String get accountGuestNotice;

  /// No description provided for @reauthNotice.
  ///
  /// In en, this message translates to:
  /// **'To connect to server, please sign in again. Notes are available locally.'**
  String get reauthNotice;

  /// No description provided for @unconfiguredNotice.
  ///
  /// In en, this message translates to:
  /// **'Sign in is not configured in this build. You can continue working locally.'**
  String get unconfiguredNotice;

  /// No description provided for @emailConfirmationNotice.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email using the link in the message, then sign in.'**
  String get emailConfirmationNotice;

  /// No description provided for @localNotes.
  ///
  /// In en, this message translates to:
  /// **'Local notes'**
  String get localNotes;

  /// No description provided for @syncReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to sync'**
  String get syncReady;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncing;

  /// No description provided for @synced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get synced;

  /// No description provided for @syncOffline.
  ///
  /// In en, this message translates to:
  /// **'No network · saved locally'**
  String get syncOffline;

  /// No description provided for @syncConflict.
  ///
  /// In en, this message translates to:
  /// **'Version conflict'**
  String get syncConflict;

  /// No description provided for @syncSetupRequired.
  ///
  /// In en, this message translates to:
  /// **'Sync server is not configured'**
  String get syncSetupRequired;

  /// No description provided for @syncAuthRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in required'**
  String get syncAuthRequired;

  /// No description provided for @syncError.
  ///
  /// In en, this message translates to:
  /// **'Could not sync'**
  String get syncError;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @resolveConflicts.
  ///
  /// In en, this message translates to:
  /// **'Resolve conflicts'**
  String get resolveConflicts;

  /// No description provided for @backupBeforeConflict.
  ///
  /// In en, this message translates to:
  /// **'Backup before resolving conflict'**
  String get backupBeforeConflict;

  /// No description provided for @waitingToSend.
  ///
  /// In en, this message translates to:
  /// **'Pending changes: {count}'**
  String waitingToSend(int count);

  /// No description provided for @conflictDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Version Conflict'**
  String get conflictDialogTitle;

  /// No description provided for @conflictDialogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Both versions are saved. A local workspace backup is created before choosing.'**
  String get conflictDialogSubtitle;

  /// No description provided for @onThisDevice.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get onThisDevice;

  /// No description provided for @inCloud.
  ///
  /// In en, this message translates to:
  /// **'In the cloud'**
  String get inCloud;

  /// No description provided for @acceptCloud.
  ///
  /// In en, this message translates to:
  /// **'Accept cloud'**
  String get acceptCloud;

  /// No description provided for @keepLocal.
  ///
  /// In en, this message translates to:
  /// **'Keep mine'**
  String get keepLocal;

  /// No description provided for @noBackupsYet.
  ///
  /// In en, this message translates to:
  /// **'No saved backups yet.'**
  String get noBackupsYet;

  /// No description provided for @backupSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Backup saved. It can be restored via workspace import.'**
  String get backupSavedSuccess;

  /// No description provided for @failedToSaveBackup.
  ///
  /// In en, this message translates to:
  /// **'Could not save backup file.'**
  String get failedToSaveBackup;

  /// No description provided for @exportImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get exportImportTitle;

  /// No description provided for @tabExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get tabExport;

  /// No description provided for @tabImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get tabImport;

  /// No description provided for @tabNotionCsv.
  ///
  /// In en, this message translates to:
  /// **'Notion / CSV'**
  String get tabNotionCsv;

  /// No description provided for @tabWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get tabWorkspace;

  /// No description provided for @copyMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Copy Markdown'**
  String get copyMarkdown;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied!'**
  String get copied;

  /// No description provided for @saveMarkdownToFile.
  ///
  /// In en, this message translates to:
  /// **'Save to File'**
  String get saveMarkdownToFile;

  /// No description provided for @createWorkspaceBackup.
  ///
  /// In en, this message translates to:
  /// **'Create Backup'**
  String get createWorkspaceBackup;

  /// No description provided for @restoreWorkspaceBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore Backup'**
  String get restoreWorkspaceBackup;

  /// No description provided for @noNoteSelected.
  ///
  /// In en, this message translates to:
  /// **'No Note Selected'**
  String get noNoteSelected;

  /// No description provided for @noNoteSelectedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select a note from the sidebar or create a new one'**
  String get noNoteSelectedSubtitle;

  /// No description provided for @newNote.
  ///
  /// In en, this message translates to:
  /// **'New Note'**
  String get newNote;

  /// No description provided for @pageOptions.
  ///
  /// In en, this message translates to:
  /// **'Page options'**
  String get pageOptions;

  /// No description provided for @styleSection.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get styleSection;

  /// No description provided for @smallText.
  ///
  /// In en, this message translates to:
  /// **'Small text'**
  String get smallText;

  /// No description provided for @fullWidth.
  ///
  /// In en, this message translates to:
  /// **'Full width'**
  String get fullWidth;

  /// No description provided for @failedToSavePageSettings.
  ///
  /// In en, this message translates to:
  /// **'Failed to save page settings'**
  String get failedToSavePageSettings;

  /// No description provided for @noNotesYet.
  ///
  /// In en, this message translates to:
  /// **'No notes yet\nClick + to create'**
  String get noNotesYet;

  /// No description provided for @moveToRoot.
  ///
  /// In en, this message translates to:
  /// **'Move to Root'**
  String get moveToRoot;

  /// No description provided for @pageSection.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get pageSection;

  /// No description provided for @copyLinkToPage.
  ///
  /// In en, this message translates to:
  /// **'Copy link to page'**
  String get copyLinkToPage;

  /// No description provided for @subpagesSection.
  ///
  /// In en, this message translates to:
  /// **'Subpages'**
  String get subpagesSection;

  /// No description provided for @layoutList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get layoutList;

  /// No description provided for @layoutCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get layoutCards;

  /// No description provided for @databaseUnknownTag.
  ///
  /// In en, this message translates to:
  /// **'Unknown tag'**
  String get databaseUnknownTag;

  /// No description provided for @databaseCellChangedAgain.
  ///
  /// In en, this message translates to:
  /// **'This cell changed again. Review the new value before saving.'**
  String get databaseCellChangedAgain;

  /// No description provided for @databaseCellConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Cell changed elsewhere'**
  String get databaseCellConflictTitle;

  /// No description provided for @databaseCellConflictBase.
  ///
  /// In en, this message translates to:
  /// **'Before editing'**
  String get databaseCellConflictBase;

  /// No description provided for @databaseCellConflictRemote.
  ///
  /// In en, this message translates to:
  /// **'Current database value'**
  String get databaseCellConflictRemote;

  /// No description provided for @databaseCellConflictLocal.
  ///
  /// In en, this message translates to:
  /// **'Your draft'**
  String get databaseCellConflictLocal;

  /// No description provided for @databaseCellKeepLocal.
  ///
  /// In en, this message translates to:
  /// **'Save my version'**
  String get databaseCellKeepLocal;

  /// No description provided for @databaseCellUseRemote.
  ///
  /// In en, this message translates to:
  /// **'Use the new value'**
  String get databaseCellUseRemote;

  /// No description provided for @databaseCellConflicts.
  ///
  /// In en, this message translates to:
  /// **'Cell conflicts: {count}'**
  String databaseCellConflicts(Object count);

  /// No description provided for @databaseUnsavedCellsTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved cells'**
  String get databaseUnsavedCellsTitle;

  /// No description provided for @databaseUnsavedCellsHelp.
  ///
  /// In en, this message translates to:
  /// **'Copy the draft text below if needed. Retry saving, or discard failed edits and use the values stored in the database.'**
  String get databaseUnsavedCellsHelp;

  /// No description provided for @databaseCellSavesPending.
  ///
  /// In en, this message translates to:
  /// **'Saving cells: {count}'**
  String databaseCellSavesPending(Object count);

  /// No description provided for @databaseCellSavesFailed.
  ///
  /// In en, this message translates to:
  /// **'Unsaved cells: {count}'**
  String databaseCellSavesFailed(Object count);

  /// No description provided for @databaseSummaryScope.
  ///
  /// In en, this message translates to:
  /// **'All rows in the current selection, across every page'**
  String get databaseSummaryScope;

  /// No description provided for @importExportSection.
  ///
  /// In en, this message translates to:
  /// **'Import and export'**
  String get importExportSection;

  /// No description provided for @exportSection.
  ///
  /// In en, this message translates to:
  /// **'Export Page'**
  String get exportSection;

  /// No description provided for @exportMarkdownEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Export Markdown...'**
  String get exportMarkdownEllipsis;

  /// No description provided for @saveMdToDownloads.
  ///
  /// In en, this message translates to:
  /// **'Save .md to Downloads'**
  String get saveMdToDownloads;

  /// No description provided for @importSection.
  ///
  /// In en, this message translates to:
  /// **'Import Content'**
  String get importSection;

  /// No description provided for @importNotionCsvEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Import Notion / CSV...'**
  String get importNotionCsvEllipsis;

  /// No description provided for @importMarkdownEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Import Markdown (.md)...'**
  String get importMarkdownEllipsis;

  /// No description provided for @backupRestoreEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore...'**
  String get backupRestoreEllipsis;

  /// No description provided for @workspaceSection.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspaceSection;

  /// No description provided for @decideLater.
  ///
  /// In en, this message translates to:
  /// **'Decide later'**
  String get decideLater;

  /// No description provided for @useSavedVersion.
  ///
  /// In en, this message translates to:
  /// **'Use saved version'**
  String get useSavedVersion;

  /// No description provided for @useLocalDraft.
  ///
  /// In en, this message translates to:
  /// **'Use local draft'**
  String get useLocalDraft;

  /// No description provided for @wipeExistingWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Erase existing pages before restore'**
  String get wipeExistingWorkspace;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search pages or type to create...'**
  String get searchPlaceholder;

  /// No description provided for @recentPages.
  ///
  /// In en, this message translates to:
  /// **'RECENT PAGES'**
  String get recentPages;

  /// No description provided for @pagesCategory.
  ///
  /// In en, this message translates to:
  /// **'PAGES'**
  String get pagesCategory;

  /// No description provided for @noMatchingNotes.
  ///
  /// In en, this message translates to:
  /// **'No matching notes'**
  String get noMatchingNotes;

  /// No description provided for @createPageAction.
  ///
  /// In en, this message translates to:
  /// **'Create page '**
  String get createPageAction;

  /// No description provided for @navigateShortcut.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get navigateShortcut;

  /// No description provided for @openShortcut.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openShortcut;

  /// No description provided for @closeShortcut.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeShortcut;

  /// No description provided for @itemsFound.
  ///
  /// In en, this message translates to:
  /// **'{count} found'**
  String itemsFound(int count);

  /// No description provided for @pageCoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Page Cover'**
  String get pageCoverTitle;

  /// No description provided for @tabGradients.
  ///
  /// In en, this message translates to:
  /// **'Gradients'**
  String get tabGradients;

  /// No description provided for @tabSolidColors.
  ///
  /// In en, this message translates to:
  /// **'Solid Colors'**
  String get tabSolidColors;

  /// No description provided for @selectIconTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Icon'**
  String get selectIconTitle;

  /// No description provided for @randomIcon.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get randomIcon;

  /// No description provided for @filterEmojiHint.
  ///
  /// In en, this message translates to:
  /// **'Filter emoji or paste custom...'**
  String get filterEmojiHint;

  /// No description provided for @categoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get categoryAll;

  /// No description provided for @currentIcon.
  ///
  /// In en, this message translates to:
  /// **'Current: {emoji}'**
  String currentIcon(String emoji);

  /// No description provided for @linkToPageHint.
  ///
  /// In en, this message translates to:
  /// **'Link to page...'**
  String get linkToPageHint;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @noPagesFound.
  ///
  /// In en, this message translates to:
  /// **'No pages found'**
  String get noPagesFound;

  /// No description provided for @selectShortcut.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get selectShortcut;

  /// No description provided for @cancelShortcut.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelShortcut;

  /// No description provided for @tabExportMd.
  ///
  /// In en, this message translates to:
  /// **'Export (.md)'**
  String get tabExportMd;

  /// No description provided for @tabImportMd.
  ///
  /// In en, this message translates to:
  /// **'Import (.md)'**
  String get tabImportMd;

  /// No description provided for @tabBackupJson.
  ///
  /// In en, this message translates to:
  /// **'Backup (JSON)'**
  String get tabBackupJson;

  /// No description provided for @selectPageToExport.
  ///
  /// In en, this message translates to:
  /// **'Select a page to export as Markdown'**
  String get selectPageToExport;

  /// No description provided for @copyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to Clipboard'**
  String get copyToClipboard;

  /// No description provided for @importAsNewPage.
  ///
  /// In en, this message translates to:
  /// **'Import as New Page'**
  String get importAsNewPage;

  /// No description provided for @loadFile.
  ///
  /// In en, this message translates to:
  /// **'Load File'**
  String get loadFile;

  /// No description provided for @importAsNewDatabasePage.
  ///
  /// In en, this message translates to:
  /// **'Import as New Database Page'**
  String get importAsNewDatabasePage;

  /// No description provided for @browse.
  ///
  /// In en, this message translates to:
  /// **'Browse...'**
  String get browse;

  /// No description provided for @tablePreview.
  ///
  /// In en, this message translates to:
  /// **'Table Preview'**
  String get tablePreview;

  /// No description provided for @rawCsv.
  ///
  /// In en, this message translates to:
  /// **'Raw CSV'**
  String get rawCsv;

  /// No description provided for @exportWorkspaceBackup.
  ///
  /// In en, this message translates to:
  /// **'Export Workspace Backup'**
  String get exportWorkspaceBackup;

  /// No description provided for @restoreWorkspaceFromJson.
  ///
  /// In en, this message translates to:
  /// **'Restore Workspace from JSON'**
  String get restoreWorkspaceFromJson;

  /// No description provided for @saveBackupToDownloads.
  ///
  /// In en, this message translates to:
  /// **'Save Backup to Downloads'**
  String get saveBackupToDownloads;

  /// No description provided for @restoreWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Restore Workspace'**
  String get restoreWorkspace;

  /// No description provided for @databaseAddProperty.
  ///
  /// In en, this message translates to:
  /// **'Add property'**
  String get databaseAddProperty;

  /// No description provided for @databaseRename.
  ///
  /// In en, this message translates to:
  /// **'Rename database'**
  String get databaseRename;

  /// No description provided for @databaseSearch.
  ///
  /// In en, this message translates to:
  /// **'Search database'**
  String get databaseSearch;

  /// No description provided for @databaseFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get databaseFilter;

  /// No description provided for @databaseSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get databaseSort;

  /// No description provided for @databaseOptions.
  ///
  /// In en, this message translates to:
  /// **'Database options'**
  String get databaseOptions;

  /// No description provided for @databaseSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get databaseSearchPlaceholder;

  /// No description provided for @databaseCloseSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get databaseCloseSearch;

  /// No description provided for @databaseFilterCount.
  ///
  /// In en, this message translates to:
  /// **'Filter ({count})'**
  String databaseFilterCount(int count);

  /// No description provided for @databaseClearSort.
  ///
  /// In en, this message translates to:
  /// **'Clear sort'**
  String get databaseClearSort;

  /// No description provided for @databaseSortAscending.
  ///
  /// In en, this message translates to:
  /// **'Ascending ↑'**
  String get databaseSortAscending;

  /// No description provided for @databaseSortDescending.
  ///
  /// In en, this message translates to:
  /// **'Descending ↓'**
  String get databaseSortDescending;

  /// No description provided for @databaseMoreCreationOptions.
  ///
  /// In en, this message translates to:
  /// **'More creation options'**
  String get databaseMoreCreationOptions;

  /// No description provided for @columnMoveLeft.
  ///
  /// In en, this message translates to:
  /// **'Move left'**
  String get columnMoveLeft;

  /// No description provided for @columnMoveRight.
  ///
  /// In en, this message translates to:
  /// **'Move right'**
  String get columnMoveRight;

  /// No description provided for @columnSortAscending.
  ///
  /// In en, this message translates to:
  /// **'Sort ascending'**
  String get columnSortAscending;

  /// No description provided for @columnSortDescending.
  ///
  /// In en, this message translates to:
  /// **'Sort descending'**
  String get columnSortDescending;

  /// No description provided for @columnDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete column'**
  String get columnDelete;

  /// No description provided for @propTypeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get propTypeText;

  /// No description provided for @propTypeNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get propTypeNumber;

  /// No description provided for @propTypeSelect.
  ///
  /// In en, this message translates to:
  /// **'Select (Tags)'**
  String get propTypeSelect;

  /// No description provided for @propTypeMultiSelect.
  ///
  /// In en, this message translates to:
  /// **'Multi-select'**
  String get propTypeMultiSelect;

  /// No description provided for @propTypeStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get propTypeStatus;

  /// No description provided for @propTypeCheckbox.
  ///
  /// In en, this message translates to:
  /// **'Checkbox'**
  String get propTypeCheckbox;

  /// No description provided for @propTypeDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get propTypeDate;

  /// No description provided for @propTypeUrl.
  ///
  /// In en, this message translates to:
  /// **'URL Link'**
  String get propTypeUrl;

  /// No description provided for @statusNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get statusNotStarted;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get statusInProgress;

  /// No description provided for @statusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get statusDone;

  /// No description provided for @propertyNameHint.
  ///
  /// In en, this message translates to:
  /// **'Property name'**
  String get propertyNameHint;

  /// No description provided for @propertyDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get propertyDefault;

  /// No description provided for @propertyNumberFormat.
  ///
  /// In en, this message translates to:
  /// **'Number format'**
  String get propertyNumberFormat;

  /// No description provided for @propertyDecimalPlaces.
  ///
  /// In en, this message translates to:
  /// **'Decimal places'**
  String get propertyDecimalPlaces;

  /// No description provided for @propertyShowAs.
  ///
  /// In en, this message translates to:
  /// **'Show as'**
  String get propertyShowAs;

  /// No description provided for @propertyShowAsNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get propertyShowAsNumber;

  /// No description provided for @propertyShowAsBar.
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get propertyShowAsBar;

  /// No description provided for @propertyShowAsRing.
  ///
  /// In en, this message translates to:
  /// **'Ring'**
  String get propertyShowAsRing;

  /// No description provided for @propertyDivideBy.
  ///
  /// In en, this message translates to:
  /// **'Divide by'**
  String get propertyDivideBy;

  /// No description provided for @propertyFilterFormats.
  ///
  /// In en, this message translates to:
  /// **'Filter formats...'**
  String get propertyFilterFormats;

  /// No description provided for @propertyScopeHint.
  ///
  /// In en, this message translates to:
  /// **'Changes apply to all views showing this property.'**
  String get propertyScopeHint;

  /// No description provided for @propertyAdding.
  ///
  /// In en, this message translates to:
  /// **'Adding...'**
  String get propertyAdding;

  /// No description provided for @propertyError.
  ///
  /// In en, this message translates to:
  /// **'Could not add property. Try again.'**
  String get propertyError;

  /// No description provided for @cellClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get cellClearSelection;

  /// No description provided for @cellNewTag.
  ///
  /// In en, this message translates to:
  /// **'New tag...'**
  String get cellNewTag;

  /// No description provided for @cellNewStatus.
  ///
  /// In en, this message translates to:
  /// **'New status...'**
  String get cellNewStatus;

  /// No description provided for @cellAddStatus.
  ///
  /// In en, this message translates to:
  /// **'+ Status'**
  String get cellAddStatus;

  /// No description provided for @cellAddMultiSelect.
  ///
  /// In en, this message translates to:
  /// **'+ Tags'**
  String get cellAddMultiSelect;

  /// No description provided for @cellUntitledPage.
  ///
  /// In en, this message translates to:
  /// **'Untitled page'**
  String get cellUntitledPage;

  /// No description provided for @cellTypeText.
  ///
  /// In en, this message translates to:
  /// **'Type text...'**
  String get cellTypeText;

  /// No description provided for @cellCouldNotSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save this cell. Check that the row and column still exist, then try again.'**
  String get cellCouldNotSave;

  /// No description provided for @filterDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter Database'**
  String get filterDialogTitle;

  /// No description provided for @filterActiveRules.
  ///
  /// In en, this message translates to:
  /// **'Active Rules'**
  String get filterActiveRules;

  /// No description provided for @filterAddFilter.
  ///
  /// In en, this message translates to:
  /// **'Add Filter'**
  String get filterAddFilter;

  /// No description provided for @filterCheckedOnly.
  ///
  /// In en, this message translates to:
  /// **'Checked only'**
  String get filterCheckedOnly;

  /// No description provided for @filterUncheckedOnly.
  ///
  /// In en, this message translates to:
  /// **'Unchecked only'**
  String get filterUncheckedOnly;

  /// No description provided for @filterHasDate.
  ///
  /// In en, this message translates to:
  /// **'Has date'**
  String get filterHasDate;

  /// No description provided for @filterNoDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get filterNoDate;

  /// No description provided for @filterHasTag.
  ///
  /// In en, this message translates to:
  /// **'Has tag (Not empty)'**
  String get filterHasTag;

  /// No description provided for @filterNoTag.
  ///
  /// In en, this message translates to:
  /// **'No tag (Empty)'**
  String get filterNoTag;

  /// No description provided for @filterContainsUrl.
  ///
  /// In en, this message translates to:
  /// **'Contains URL / domain'**
  String get filterContainsUrl;

  /// No description provided for @durationTitle.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get durationTitle;

  /// No description provided for @durationDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get durationDays;

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get durationHours;

  /// No description provided for @durationMins.
  ///
  /// In en, this message translates to:
  /// **'Mins'**
  String get durationMins;

  /// No description provided for @durationSecs.
  ///
  /// In en, this message translates to:
  /// **'Secs'**
  String get durationSecs;

  /// No description provided for @rowOpenAsPage.
  ///
  /// In en, this message translates to:
  /// **'Open as page'**
  String get rowOpenAsPage;

  /// No description provided for @rowOpenFullPage.
  ///
  /// In en, this message translates to:
  /// **'Open full page'**
  String get rowOpenFullPage;

  /// No description provided for @rowMoveToTrash.
  ///
  /// In en, this message translates to:
  /// **'Move row to trash'**
  String get rowMoveToTrash;

  /// No description provided for @databaseItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String databaseItemsCount(int count);

  /// No description provided for @databaseFilteredItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{filtered} of {total}'**
  String databaseFilteredItemsCount(int filtered, int total);

  /// No description provided for @databasePreviousRows.
  ///
  /// In en, this message translates to:
  /// **'Previous rows'**
  String get databasePreviousRows;

  /// No description provided for @databaseNextRows.
  ///
  /// In en, this message translates to:
  /// **'Next rows'**
  String get databaseNextRows;

  /// No description provided for @databasePageRange.
  ///
  /// In en, this message translates to:
  /// **'{from}–{to} of {total}'**
  String databasePageRange(int from, int to, int total);

  /// No description provided for @databaseAddTextAbove.
  ///
  /// In en, this message translates to:
  /// **'Add text above'**
  String get databaseAddTextAbove;

  /// No description provided for @databaseAddTextBelow.
  ///
  /// In en, this message translates to:
  /// **'Add text below'**
  String get databaseAddTextBelow;

  /// No description provided for @databaseLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load rows. Retry'**
  String get databaseLoadError;

  /// No description provided for @codeCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get codeCopy;

  /// No description provided for @codePaste.
  ///
  /// In en, this message translates to:
  /// **'Paste code'**
  String get codePaste;

  /// No description provided for @codeCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse code'**
  String get codeCollapse;

  /// No description provided for @codeExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand code'**
  String get codeExpand;

  /// No description provided for @codeShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show more ({count} lines)'**
  String codeShowMore(int count);

  /// No description provided for @codePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'// Type code here...'**
  String get codePlaceholder;

  /// No description provided for @codeLanguageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Language: {language}'**
  String codeLanguageTooltip(String language);

  /// No description provided for @savingStatus.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get savingStatus;

  /// No description provided for @savedStatus.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedStatus;

  /// No description provided for @saveConflictDraft.
  ///
  /// In en, this message translates to:
  /// **'Conflict — draft kept locally'**
  String get saveConflictDraft;

  /// No description provided for @saveError.
  ///
  /// In en, this message translates to:
  /// **'Save error'**
  String get saveError;

  /// No description provided for @failedToSaveSubpageLayout.
  ///
  /// In en, this message translates to:
  /// **'Could not save subpages layout. Please try again.'**
  String get failedToSaveSubpageLayout;

  /// No description provided for @failedToSaveBeforeAccountSwitch.
  ///
  /// In en, this message translates to:
  /// **'Could not save note. Please retry saving before switching accounts.'**
  String get failedToSaveBeforeAccountSwitch;

  /// No description provided for @collapsePage.
  ///
  /// In en, this message translates to:
  /// **'Collapse page'**
  String get collapsePage;

  /// No description provided for @expandPage.
  ///
  /// In en, this message translates to:
  /// **'Expand page'**
  String get expandPage;

  /// No description provided for @urlAdd.
  ///
  /// In en, this message translates to:
  /// **'Add URL'**
  String get urlAdd;

  /// No description provided for @urlOpenInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get urlOpenInBrowser;

  /// No description provided for @urlCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get urlCopyLink;

  /// No description provided for @urlCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied!'**
  String get urlCopied;

  /// No description provided for @urlEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit URL'**
  String get urlEdit;

  /// No description provided for @urlClear.
  ///
  /// In en, this message translates to:
  /// **'Clear URL'**
  String get urlClear;

  /// No description provided for @urlClickToOpenTooltip.
  ///
  /// In en, this message translates to:
  /// **'{url}\nClick to open • Double-click to edit'**
  String urlClickToOpenTooltip(String url);

  /// No description provided for @numericInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a number, for example 12.5 or 12,5.'**
  String get numericInvalidNumber;

  /// No description provided for @numericInvalidDuration.
  ///
  /// In en, this message translates to:
  /// **'Enter a duration: 1h 30m, 01:30:00, or seconds.'**
  String get numericInvalidDuration;

  /// No description provided for @numericNonFinite.
  ///
  /// In en, this message translates to:
  /// **'The number must be finite.'**
  String get numericNonFinite;

  /// No description provided for @numericFormulaUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Formulas are not supported. Enter the calculated value.'**
  String get numericFormulaUnsupported;

  /// No description provided for @numericSeparators.
  ///
  /// In en, this message translates to:
  /// **'Use a point or comma for decimals and spaces for thousands.'**
  String get numericSeparators;

  /// No description provided for @numericTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The value is too large.'**
  String get numericTooLarge;

  /// No description provided for @numericInvalidStatus.
  ///
  /// In en, this message translates to:
  /// **'Correct invalid cell values'**
  String get numericInvalidStatus;

  /// No description provided for @durationNegative.
  ///
  /// In en, this message translates to:
  /// **'Negative duration'**
  String get durationNegative;

  /// No description provided for @durationInvalidFields.
  ///
  /// In en, this message translates to:
  /// **'Use whole days, hours 0–23, minutes 0–59, and seconds below 60.'**
  String get durationInvalidFields;

  /// No description provided for @databasePasteTitle.
  ///
  /// In en, this message translates to:
  /// **'Range not changed'**
  String get databasePasteTitle;

  /// No description provided for @databasePasteMalformed.
  ///
  /// In en, this message translates to:
  /// **'Invalid TSV quoting. Copy the cells again.'**
  String get databasePasteMalformed;

  /// No description provided for @databasePasteRagged.
  ///
  /// In en, this message translates to:
  /// **'Every row must have the same number of columns.'**
  String get databasePasteRagged;

  /// No description provided for @databasePasteTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Paste up to 2,000 cells and 2 million characters at a time.'**
  String get databasePasteTooLarge;

  /// No description provided for @databasePasteBounds.
  ///
  /// In en, this message translates to:
  /// **'The range does not fit on this table page. Choose a smaller range or another starting cell.'**
  String get databasePasteBounds;

  /// No description provided for @databasePasteShape.
  ///
  /// In en, this message translates to:
  /// **'The copied range must match the selection size. One value can fill the entire selection.'**
  String get databasePasteShape;

  /// No description provided for @databasePasteCheckbox.
  ///
  /// In en, this message translates to:
  /// **'Use TRUE/FALSE, 1/0, or yes/no for a checkbox.'**
  String get databasePasteCheckbox;

  /// No description provided for @databasePasteDate.
  ///
  /// In en, this message translates to:
  /// **'Use a valid date in YYYY-MM-DD format (1970–2100).'**
  String get databasePasteDate;

  /// No description provided for @databasePasteUrl.
  ///
  /// In en, this message translates to:
  /// **'Use an HTTP, HTTPS, or mailto address.'**
  String get databasePasteUrl;

  /// No description provided for @databasePasteTag.
  ///
  /// In en, this message translates to:
  /// **'Use existing, unambiguous tag names. Separate multiple tags with commas or use a JSON list of names.'**
  String get databasePasteTag;

  /// No description provided for @databasePasteUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This value is not supported by the column.'**
  String get databasePasteUnsupported;

  /// No description provided for @databasePasteConflict.
  ///
  /// In en, this message translates to:
  /// **'Cells or column settings have changed. Refresh the range and try again. No cells were overwritten.'**
  String get databasePasteConflict;

  /// No description provided for @databasePasteDrafts.
  ///
  /// In en, this message translates to:
  /// **'Finish editing and resolve unsaved values in the target cells first.'**
  String get databasePasteDrafts;

  /// No description provided for @databasePasteBusy.
  ///
  /// In en, this message translates to:
  /// **'Wait for the current range operation to finish.'**
  String get databasePasteBusy;

  /// No description provided for @databasePasteFailed.
  ///
  /// In en, this message translates to:
  /// **'The range could not be saved. No changes were applied.'**
  String get databasePasteFailed;

  /// No description provided for @databasePasteNothingUndo.
  ///
  /// In en, this message translates to:
  /// **'No range paste to undo.'**
  String get databasePasteNothingUndo;

  /// No description provided for @databasePasteNothingRedo.
  ///
  /// In en, this message translates to:
  /// **'No range paste to redo.'**
  String get databasePasteNothingRedo;

  /// No description provided for @databasePasteUnchanged.
  ///
  /// In en, this message translates to:
  /// **'The cells already contain these values.'**
  String get databasePasteUnchanged;

  /// No description provided for @databasePasteUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo paste'**
  String get databasePasteUndo;

  /// No description provided for @databasePasteRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo paste'**
  String get databasePasteRedo;

  /// No description provided for @databasePasteSaved.
  ///
  /// In en, this message translates to:
  /// **'Pasted cells: {count}'**
  String databasePasteSaved(int count);

  /// No description provided for @databasePasteUndone.
  ///
  /// In en, this message translates to:
  /// **'Paste undone. Cells restored: {count}'**
  String databasePasteUndone(int count);

  /// No description provided for @databasePasteRedone.
  ///
  /// In en, this message translates to:
  /// **'Paste redone. Cells restored: {count}'**
  String databasePasteRedone(int count);

  /// No description provided for @databasePasteCellError.
  ///
  /// In en, this message translates to:
  /// **'Row {row}, {column}: {message}'**
  String databasePasteCellError(int row, String column, String message);

  /// No description provided for @databaseSelectRow.
  ///
  /// In en, this message translates to:
  /// **'Select row; double-click to open page'**
  String get databaseSelectRow;

  /// No description provided for @databaseSelectColumn.
  ///
  /// In en, this message translates to:
  /// **'Select column (Ctrl+Space)'**
  String get databaseSelectColumn;

  /// No description provided for @databaseSelectPage.
  ///
  /// In en, this message translates to:
  /// **'Select this table page'**
  String get databaseSelectPage;

  /// No description provided for @databaseSelectionScope.
  ///
  /// In en, this message translates to:
  /// **'Selection on the current loaded table page'**
  String get databaseSelectionScope;

  /// No description provided for @databaseSelectionSize.
  ///
  /// In en, this message translates to:
  /// **'{rows} × {columns} · cells: {cells}'**
  String databaseSelectionSize(int rows, int columns, int cells);

  /// No description provided for @coverToPanelTop.
  ///
  /// In en, this message translates to:
  /// **'Extend cover to panel top'**
  String get coverToPanelTop;

  /// No description provided for @coverBelowToolbar.
  ///
  /// In en, this message translates to:
  /// **'Place cover below toolbar'**
  String get coverBelowToolbar;

  /// No description provided for @blockMoveHandle.
  ///
  /// In en, this message translates to:
  /// **'Drag to move · Click for actions'**
  String get blockMoveHandle;

  /// No description provided for @blockMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move above'**
  String get blockMoveUp;

  /// No description provided for @blockMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move below'**
  String get blockMoveDown;

  /// No description provided for @blockInsertAbove.
  ///
  /// In en, this message translates to:
  /// **'Insert block above'**
  String get blockInsertAbove;

  /// No description provided for @blockInsertBelow.
  ///
  /// In en, this message translates to:
  /// **'Insert block below'**
  String get blockInsertBelow;

  /// No description provided for @blockCode.
  ///
  /// In en, this message translates to:
  /// **'Code block'**
  String get blockCode;

  /// No description provided for @blockText.
  ///
  /// In en, this message translates to:
  /// **'Text block'**
  String get blockText;

  /// No description provided for @blockDatabase.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get blockDatabase;

  /// No description provided for @codeTitlePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Block name'**
  String get codeTitlePlaceholder;

  /// No description provided for @codeMoreActions.
  ///
  /// In en, this message translates to:
  /// **'Code block actions'**
  String get codeMoreActions;

  /// No description provided for @trashEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Deleted pages, databases and rows appear here until permanently deleted.'**
  String get trashEmptyDescription;

  /// No description provided for @trashActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not complete this trash action. Your data has been kept. Try again.'**
  String get trashActionFailed;

  /// No description provided for @trashLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the trash.'**
  String get trashLoadFailed;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsTabGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsTabGeneral;

  /// No description provided for @generalSettingsHelp.
  ///
  /// In en, this message translates to:
  /// **'Appearance and app behavior'**
  String get generalSettingsHelp;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsAutoApply.
  ///
  /// In en, this message translates to:
  /// **'Changes apply automatically.'**
  String get settingsAutoApply;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeHelp.
  ///
  /// In en, this message translates to:
  /// **'Application appearance'**
  String get themeHelp;

  /// No description provided for @themeAuto.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get themeAuto;

  /// No description provided for @themeSystemShort.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystemShort;

  /// No description provided for @themeLightShort.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLightShort;

  /// No description provided for @themeDarkShort.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDarkShort;

  /// No description provided for @languageHelp.
  ///
  /// In en, this message translates to:
  /// **'Interface language'**
  String get languageHelp;

  /// No description provided for @workspaceBackupHelp.
  ///
  /// In en, this message translates to:
  /// **'Export and restore workspace in JSON'**
  String get workspaceBackupHelp;

  /// No description provided for @openAction.
  ///
  /// In en, this message translates to:
  /// **'Open…'**
  String get openAction;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String appVersion(String version);

  /// No description provided for @sync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get sync;

  /// No description provided for @syncHelp.
  ///
  /// In en, this message translates to:
  /// **'Notes are stored on this computer. A server is only needed to keep them in sync across your other devices.'**
  String get syncHelp;

  /// No description provided for @syncTabSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get syncTabSignIn;

  /// No description provided for @syncTabSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get syncTabSignUp;

  /// No description provided for @syncSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String syncSignedInAs(String email);

  /// No description provided for @syncSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get syncSignOut;

  /// No description provided for @menuCallout.
  ///
  /// In en, this message translates to:
  /// **'Callout'**
  String get menuCallout;

  /// No description provided for @menuToggle.
  ///
  /// In en, this message translates to:
  /// **'Toggle list'**
  String get menuToggle;

  /// No description provided for @calloutPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Write a callout...'**
  String get calloutPlaceholder;

  /// No description provided for @togglePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Toggle'**
  String get togglePlaceholder;

  /// No description provided for @toggleEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Empty toggle. Click to add content'**
  String get toggleEmptyHint;

  /// No description provided for @blockCallout.
  ///
  /// In en, this message translates to:
  /// **'Callout'**
  String get blockCallout;

  /// No description provided for @blockToggle.
  ///
  /// In en, this message translates to:
  /// **'Toggle'**
  String get blockToggle;

  /// No description provided for @blockImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get blockImage;

  /// No description provided for @dropImageHint.
  ///
  /// In en, this message translates to:
  /// **'Drop image to insert'**
  String get dropImageHint;

  /// No description provided for @turnInto.
  ///
  /// In en, this message translates to:
  /// **'Turn into'**
  String get turnInto;

  /// No description provided for @turnIntoText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get turnIntoText;

  /// No description provided for @turnIntoH1.
  ///
  /// In en, this message translates to:
  /// **'Heading 1'**
  String get turnIntoH1;

  /// No description provided for @turnIntoH2.
  ///
  /// In en, this message translates to:
  /// **'Heading 2'**
  String get turnIntoH2;

  /// No description provided for @turnIntoH3.
  ///
  /// In en, this message translates to:
  /// **'Heading 3'**
  String get turnIntoH3;

  /// No description provided for @turnIntoBulletList.
  ///
  /// In en, this message translates to:
  /// **'Bulleted list'**
  String get turnIntoBulletList;

  /// No description provided for @turnIntoNumberedList.
  ///
  /// In en, this message translates to:
  /// **'Numbered list'**
  String get turnIntoNumberedList;

  /// No description provided for @turnIntoTodoList.
  ///
  /// In en, this message translates to:
  /// **'To-do list'**
  String get turnIntoTodoList;

  /// No description provided for @turnIntoQuote.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get turnIntoQuote;

  /// No description provided for @turnIntoCode.
  ///
  /// In en, this message translates to:
  /// **'Code block'**
  String get turnIntoCode;

  /// No description provided for @turnIntoCallout.
  ///
  /// In en, this message translates to:
  /// **'Callout'**
  String get turnIntoCallout;

  /// No description provided for @turnIntoToggle.
  ///
  /// In en, this message translates to:
  /// **'Toggle list'**
  String get turnIntoToggle;

  /// No description provided for @copyBlockText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get copyBlockText;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @toggleSidebar.
  ///
  /// In en, this message translates to:
  /// **'Sidebar'**
  String get toggleSidebar;

  /// No description provided for @hideSidebar.
  ///
  /// In en, this message translates to:
  /// **'Hide sidebar'**
  String get hideSidebar;

  /// No description provided for @showSidebar.
  ///
  /// In en, this message translates to:
  /// **'Show sidebar'**
  String get showSidebar;

  /// No description provided for @navBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get navBack;

  /// No description provided for @navForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get navForward;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
