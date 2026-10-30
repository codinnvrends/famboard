import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('hi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'FamBoard'**
  String get appTitle;

  /// No description provided for @navToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// No description provided for @navLists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get navLists;

  /// No description provided for @navBills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get navBills;

  /// No description provided for @navFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get navFamily;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your home\'s shared board'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Note what\'s needed, what\'s broken and what\'s due. FamBoard syncs between family phones over Wi‑Fi or Bluetooth, with no internet needed.'**
  String get welcomeBody;

  /// No description provided for @createFamily.
  ///
  /// In en, this message translates to:
  /// **'Create a family'**
  String get createFamily;

  /// No description provided for @joinFamily.
  ///
  /// In en, this message translates to:
  /// **'Join a family'**
  String get joinFamily;

  /// No description provided for @familyNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Family name'**
  String get familyNameLabel;

  /// No description provided for @familyNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Sharma home'**
  String get familyNameHint;

  /// No description provided for @yourNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourNameLabel;

  /// No description provided for @yourNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Priya'**
  String get yourNameHint;

  /// No description provided for @createFamilyAction.
  ///
  /// In en, this message translates to:
  /// **'Create family'**
  String get createFamilyAction;

  /// No description provided for @scanInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan the invite QR'**
  String get scanInviteTitle;

  /// No description provided for @scanInviteBody.
  ///
  /// In en, this message translates to:
  /// **'Ask a family admin to open Family → Invite someone, then point your camera at the code.'**
  String get scanInviteBody;

  /// No description provided for @pasteInvite.
  ///
  /// In en, this message translates to:
  /// **'Paste invite code instead'**
  String get pasteInvite;

  /// No description provided for @inviteCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteCodeLabel;

  /// No description provided for @joinAction.
  ///
  /// In en, this message translates to:
  /// **'Join family'**
  String get joinAction;

  /// No description provided for @inviteExpired.
  ///
  /// In en, this message translates to:
  /// **'This invite has expired. Ask for a new QR code.'**
  String get inviteExpired;

  /// No description provided for @inviteInvalid.
  ///
  /// In en, this message translates to:
  /// **'That is not a FamBoard invite.'**
  String get inviteInvalid;

  /// No description provided for @joiningFamily.
  ///
  /// In en, this message translates to:
  /// **'Joining {name}'**
  String joiningFamily(String name);

  /// No description provided for @joinedWaitingSync.
  ///
  /// In en, this message translates to:
  /// **'You\'re in! Keep both phones open nearby to get the family\'s board.'**
  String get joinedWaitingSync;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera not available. Paste the invite code instead.'**
  String get cameraUnavailable;

  /// No description provided for @typeNeedToBuy.
  ///
  /// In en, this message translates to:
  /// **'Need to buy'**
  String get typeNeedToBuy;

  /// No description provided for @typeOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get typeOutOfStock;

  /// No description provided for @typeRepair.
  ///
  /// In en, this message translates to:
  /// **'Repair'**
  String get typeRepair;

  /// No description provided for @typeUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get typeUpgrade;

  /// No description provided for @typeBill.
  ///
  /// In en, this message translates to:
  /// **'Bill'**
  String get typeBill;

  /// No description provided for @typeTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get typeTask;

  /// No description provided for @statusProposed.
  ///
  /// In en, this message translates to:
  /// **'Proposed'**
  String get statusProposed;

  /// No description provided for @statusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get statusOpen;

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

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @priorityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get priorityNormal;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @priorityUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get priorityUrgent;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @roleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get roleMember;

  /// No description provided for @roleChild.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get roleChild;

  /// No description provided for @roleViewer.
  ///
  /// In en, this message translates to:
  /// **'Viewer'**
  String get roleViewer;

  /// No description provided for @roleAdminDesc.
  ///
  /// In en, this message translates to:
  /// **'Can do everything, including inviting and removing people'**
  String get roleAdminDesc;

  /// No description provided for @roleMemberDesc.
  ///
  /// In en, this message translates to:
  /// **'Adds, edits and completes items; sees bill amounts'**
  String get roleMemberDesc;

  /// No description provided for @roleChildDesc.
  ///
  /// In en, this message translates to:
  /// **'Adds items and completes their own; amounts hidden'**
  String get roleChildDesc;

  /// No description provided for @roleViewerDesc.
  ///
  /// In en, this message translates to:
  /// **'Sees lists and ticks off shopping, e.g. a helper'**
  String get roleViewerDesc;

  /// No description provided for @todayOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get todayOverdue;

  /// No description provided for @todayDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get todayDueToday;

  /// No description provided for @todayUrgentRepairs.
  ///
  /// In en, this message translates to:
  /// **'Urgent repairs'**
  String get todayUrgentRepairs;

  /// No description provided for @todayOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get todayOutOfStock;

  /// No description provided for @todayMine.
  ///
  /// In en, this message translates to:
  /// **'You\'re on it'**
  String get todayMine;

  /// No description provided for @todayUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Coming up this week'**
  String get todayUpcoming;

  /// No description provided for @todayAllClear.
  ///
  /// In en, this message translates to:
  /// **'All clear for today'**
  String get todayAllClear;

  /// No description provided for @todayAllClearBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing is overdue or due today. Tap + to add something.'**
  String get todayAllClearBody;

  /// No description provided for @shoppingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item to buy} other{{count} items to buy}}'**
  String shoppingCount(int count);

  /// No description provided for @startShopping.
  ///
  /// In en, this message translates to:
  /// **'Start shopping'**
  String get startShopping;

  /// No description provided for @quickAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to the board'**
  String get quickAddTitle;

  /// No description provided for @quickAddHint.
  ///
  /// In en, this message translates to:
  /// **'What\'s needed? e.g. atta 10kg, tap leaking'**
  String get quickAddHint;

  /// No description provided for @moreDetails.
  ///
  /// In en, this message translates to:
  /// **'More details'**
  String get moreDetails;

  /// No description provided for @fewerDetails.
  ///
  /// In en, this message translates to:
  /// **'Fewer details'**
  String get fewerDetails;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @typeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeLabel;

  /// No description provided for @priorityLabel.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priorityLabel;

  /// No description provided for @quantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantityLabel;

  /// No description provided for @unitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unitLabel;

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount (₹)'**
  String get amountLabel;

  /// No description provided for @dueLabel.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get dueLabel;

  /// No description provided for @noDueDate.
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get noDueDate;

  /// No description provided for @assigneeLabel.
  ///
  /// In en, this message translates to:
  /// **'Assigned to'**
  String get assigneeLabel;

  /// No description provided for @nobody.
  ///
  /// In en, this message translates to:
  /// **'Nobody'**
  String get nobody;

  /// No description provided for @repeatLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get repeatLabel;

  /// No description provided for @repeatNever.
  ///
  /// In en, this message translates to:
  /// **'Doesn\'t repeat'**
  String get repeatNever;

  /// No description provided for @repeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get repeatDaily;

  /// No description provided for @repeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get repeatWeekly;

  /// No description provided for @repeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get repeatMonthly;

  /// No description provided for @repeatQuarterly.
  ///
  /// In en, this message translates to:
  /// **'Every 3 months'**
  String get repeatQuarterly;

  /// No description provided for @repeatYearly.
  ///
  /// In en, this message translates to:
  /// **'Every year'**
  String get repeatYearly;

  /// No description provided for @repeatEveryNDays.
  ///
  /// In en, this message translates to:
  /// **'Every few days'**
  String get repeatEveryNDays;

  /// No description provided for @everyNDays.
  ///
  /// In en, this message translates to:
  /// **'Every {n} days'**
  String everyNDays(int n);

  /// No description provided for @everyNMonths.
  ///
  /// In en, this message translates to:
  /// **'Every {n} months'**
  String everyNMonths(int n);

  /// No description provided for @everyNWeeks.
  ///
  /// In en, this message translates to:
  /// **'Every {n} weeks'**
  String everyNWeeks(int n);

  /// No description provided for @monthlyOnDay.
  ///
  /// In en, this message translates to:
  /// **'Monthly on day {day}'**
  String monthlyOnDay(int day);

  /// No description provided for @weeklyOn.
  ///
  /// In en, this message translates to:
  /// **'Weekly on {day}'**
  String weeklyOn(String day);

  /// No description provided for @daysLabel.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get daysLabel;

  /// No description provided for @reminderLabel.
  ///
  /// In en, this message translates to:
  /// **'Remind early'**
  String get reminderLabel;

  /// No description provided for @reminderNone.
  ///
  /// In en, this message translates to:
  /// **'Only on the due date'**
  String get reminderNone;

  /// No description provided for @reminderDaysBefore.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 day before} other{{n} days before}}'**
  String reminderDaysBefore(int n);

  /// No description provided for @noteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get noteLabel;

  /// No description provided for @duplicateWarning.
  ///
  /// In en, this message translates to:
  /// **'Already on the board: “{title}”'**
  String duplicateWarning(String title);

  /// No description provided for @viewExisting.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewExisting;

  /// No description provided for @entryAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to the board'**
  String get entryAdded;

  /// No description provided for @voiceListening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get voiceListening;

  /// No description provided for @voiceNeedsInternet.
  ///
  /// In en, this message translates to:
  /// **'Voice needs internet here. Download the offline speech pack for this language in your phone\'s settings, or type instead.'**
  String get voiceNeedsInternet;

  /// No description provided for @voiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice input isn\'t available on this phone. You can type instead.'**
  String get voiceUnavailable;

  /// No description provided for @voicePermission.
  ///
  /// In en, this message translates to:
  /// **'Allow microphone access to use voice entry.'**
  String get voicePermission;

  /// No description provided for @voiceNoMatch.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t catch that. Try again.'**
  String get voiceNoMatch;

  /// No description provided for @voiceEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get voiceEnglish;

  /// No description provided for @voiceHindi.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी'**
  String get voiceHindi;

  /// No description provided for @learnedCategory.
  ///
  /// In en, this message translates to:
  /// **'Got it. FamBoard will remember this category.'**
  String get learnedCategory;

  /// No description provided for @markDone.
  ///
  /// In en, this message translates to:
  /// **'Mark done'**
  String get markDone;

  /// No description provided for @markBought.
  ///
  /// In en, this message translates to:
  /// **'Bought'**
  String get markBought;

  /// No description provided for @markPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark paid'**
  String get markPaid;

  /// No description provided for @startWork.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startWork;

  /// No description provided for @reopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get reopen;

  /// No description provided for @cancelEntry.
  ///
  /// In en, this message translates to:
  /// **'Cancel item'**
  String get cancelEntry;

  /// No description provided for @claim.
  ///
  /// In en, this message translates to:
  /// **'I\'ll do it'**
  String get claim;

  /// No description provided for @unclaim.
  ///
  /// In en, this message translates to:
  /// **'Let go'**
  String get unclaim;

  /// No description provided for @claimedBy.
  ///
  /// In en, this message translates to:
  /// **'{name} is on it'**
  String claimedBy(String name);

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @activityCreated.
  ///
  /// In en, this message translates to:
  /// **'{name} added this'**
  String activityCreated(String name);

  /// No description provided for @activityCreatedRecurring.
  ///
  /// In en, this message translates to:
  /// **'{name} completed the last one; this is the next'**
  String activityCreatedRecurring(String name);

  /// No description provided for @activityEdited.
  ///
  /// In en, this message translates to:
  /// **'{name} edited it'**
  String activityEdited(String name);

  /// No description provided for @activityClaimed.
  ///
  /// In en, this message translates to:
  /// **'{name} took it on'**
  String activityClaimed(String name);

  /// No description provided for @activityUnclaimed.
  ///
  /// In en, this message translates to:
  /// **'{name} let it go'**
  String activityUnclaimed(String name);

  /// No description provided for @activityStatus.
  ///
  /// In en, this message translates to:
  /// **'{name} marked it {status}'**
  String activityStatus(String name, String status);

  /// No description provided for @activityDeleted.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted it'**
  String activityDeleted(String name);

  /// No description provided for @activityRestored.
  ///
  /// In en, this message translates to:
  /// **'{name} restored it'**
  String activityRestored(String name);

  /// No description provided for @activityBought.
  ///
  /// In en, this message translates to:
  /// **'{name} bought it'**
  String activityBought(String name);

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this item?'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You can restore it from Lists → Deleted.'**
  String get deleteConfirmBody;

  /// No description provided for @entryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get entryDeleted;

  /// No description provided for @nextOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Next one added for {date}'**
  String nextOccurrence(String date);

  /// No description provided for @dueOn.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String dueOn(String date);

  /// No description provided for @overdueBy.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day overdue} other{{days} days overdue}}'**
  String overdueBy(int days);

  /// No description provided for @dueTodayShort.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get dueTodayShort;

  /// No description provided for @dueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Due tomorrow'**
  String get dueTomorrow;

  /// No description provided for @addedBy.
  ///
  /// In en, this message translates to:
  /// **'Added by {name}'**
  String addedBy(String name);

  /// No description provided for @someone.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get someone;

  /// No description provided for @deletedBadge.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deletedBadge;

  /// No description provided for @notFound.
  ///
  /// In en, this message translates to:
  /// **'This item is no longer on the board.'**
  String get notFound;

  /// No description provided for @listsAllOpen.
  ///
  /// In en, this message translates to:
  /// **'All open'**
  String get listsAllOpen;

  /// No description provided for @listsDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get listsDaily;

  /// No description provided for @listsWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get listsWeekly;

  /// No description provided for @listsMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get listsMonthly;

  /// No description provided for @listsYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get listsYearly;

  /// No description provided for @listsRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get listsRecurring;

  /// No description provided for @listsDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get listsDone;

  /// No description provided for @listsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get listsDeleted;

  /// No description provided for @listsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here'**
  String get listsEmpty;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search the board'**
  String get searchHint;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get noResults;

  /// No description provided for @billsStillToPay.
  ///
  /// In en, this message translates to:
  /// **'Still to pay this month'**
  String get billsStillToPay;

  /// No description provided for @billsPaidThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Paid this month'**
  String get billsPaidThisMonth;

  /// No description provided for @billsUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming bills'**
  String get billsUpcoming;

  /// No description provided for @billsPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid recently'**
  String get billsPaid;

  /// No description provided for @billsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No bills yet'**
  String get billsEmpty;

  /// No description provided for @billsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add one like “electricity bill 1200 by 10th”, set it to repeat monthly, and FamBoard will remind you.'**
  String get billsEmptyBody;

  /// No description provided for @billsAmountsHidden.
  ///
  /// In en, this message translates to:
  /// **'Bill amounts are visible to adults only.'**
  String get billsAmountsHidden;

  /// No description provided for @addFromSms.
  ///
  /// In en, this message translates to:
  /// **'Add from a bill SMS'**
  String get addFromSms;

  /// No description provided for @amountHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get amountHidden;

  /// No description provided for @shoppingTitle.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get shoppingTitle;

  /// No description provided for @shoppingEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to buy. Nice!'**
  String get shoppingEmpty;

  /// No description provided for @shoppingHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap an item once it\'s in your cart.'**
  String get shoppingHelp;

  /// No description provided for @shoppingBought.
  ///
  /// In en, this message translates to:
  /// **'Bought {title}'**
  String shoppingBought(String title);

  /// No description provided for @familyMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get familyMembers;

  /// No description provided for @inviteSomeone.
  ///
  /// In en, this message translates to:
  /// **'Invite someone'**
  String get inviteSomeone;

  /// No description provided for @inviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite to {family}'**
  String inviteTitle(String family);

  /// No description provided for @inviteJoinAs.
  ///
  /// In en, this message translates to:
  /// **'They join as'**
  String get inviteJoinAs;

  /// No description provided for @inviteInstructions.
  ///
  /// In en, this message translates to:
  /// **'On the other phone, open FamBoard, choose “Join a family” and scan this code. Show it only in person: anyone with it can join.'**
  String get inviteInstructions;

  /// No description provided for @inviteExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'Expires in {time}'**
  String inviteExpiresIn(String time);

  /// No description provided for @inviteExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'This code has expired'**
  String get inviteExpiredTitle;

  /// No description provided for @inviteNewCode.
  ///
  /// In en, this message translates to:
  /// **'New code'**
  String get inviteNewCode;

  /// No description provided for @inviteCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get inviteCopyCode;

  /// No description provided for @removeMember.
  ///
  /// In en, this message translates to:
  /// **'Remove from family'**
  String get removeMember;

  /// No description provided for @removeMemberConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}? Their phones will stop syncing with yours.'**
  String removeMemberConfirm(String name);

  /// No description provided for @changeRole.
  ///
  /// In en, this message translates to:
  /// **'Change role'**
  String get changeRole;

  /// No description provided for @youLabel.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get youLabel;

  /// No description provided for @removedLabel.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get removedLabel;

  /// No description provided for @syncTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncTitle;

  /// No description provided for @familyPhones.
  ///
  /// In en, this message translates to:
  /// **'Family phones'**
  String get familyPhones;

  /// No description provided for @noPhonesYet.
  ///
  /// In en, this message translates to:
  /// **'No family phones seen yet. Keep FamBoard open on both phones, on the same Wi‑Fi or with Bluetooth on.'**
  String get noPhonesYet;

  /// No description provided for @phoneLastSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced {time} via {via}'**
  String phoneLastSynced(String time, String via);

  /// No description provided for @phoneSeen.
  ///
  /// In en, this message translates to:
  /// **'Seen {time}'**
  String phoneSeen(String time);

  /// No description provided for @nearbyNow.
  ///
  /// In en, this message translates to:
  /// **'Nearby now'**
  String get nearbyNow;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncing;

  /// No description provided for @syncNever.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get syncNever;

  /// No description provided for @syncedWith.
  ///
  /// In en, this message translates to:
  /// **'Synced with {name} · {time}'**
  String syncedWith(String name, String time);

  /// No description provided for @syncStale.
  ///
  /// In en, this message translates to:
  /// **'Not synced for {days} days'**
  String syncStale(int days);

  /// No description provided for @syncSearching.
  ///
  /// In en, this message translates to:
  /// **'Looking for family phones…'**
  String get syncSearching;

  /// No description provided for @syncPeersNearby.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 family phone nearby} other{{count} family phones nearby}}'**
  String syncPeersNearby(int count);

  /// No description provided for @syncOff.
  ///
  /// In en, this message translates to:
  /// **'Sync is off'**
  String get syncOff;

  /// No description provided for @viaWifi.
  ///
  /// In en, this message translates to:
  /// **'Wi‑Fi'**
  String get viaWifi;

  /// No description provided for @viaNearby.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get viaNearby;

  /// No description provided for @viaOther.
  ///
  /// In en, this message translates to:
  /// **'direct'**
  String get viaOther;

  /// No description provided for @syncReceived.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 update from {name}} other{{count} updates from {name}}}'**
  String syncReceived(int count, String name);

  /// No description provided for @syncNoPeersToSync.
  ///
  /// In en, this message translates to:
  /// **'No family phones nearby right now.'**
  String get syncNoPeersToSync;

  /// No description provided for @renameFamily.
  ///
  /// In en, this message translates to:
  /// **'Rename family'**
  String get renameFamily;

  /// No description provided for @switchFamily.
  ///
  /// In en, this message translates to:
  /// **'Switch family'**
  String get switchFamily;

  /// No description provided for @addAnotherFamily.
  ///
  /// In en, this message translates to:
  /// **'Create or join another family'**
  String get addAnotherFamily;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Phone default'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी (Hindi)'**
  String get languageHindi;

  /// No description provided for @settingsLargeText.
  ///
  /// In en, this message translates to:
  /// **'Large text'**
  String get settingsLargeText;

  /// No description provided for @settingsLargeTextBody.
  ///
  /// In en, this message translates to:
  /// **'Bigger text and buttons, easier to read'**
  String get settingsLargeTextBody;

  /// No description provided for @settingsReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get settingsReminders;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsDigestTime.
  ///
  /// In en, this message translates to:
  /// **'Daily summary'**
  String get settingsDigestTime;

  /// No description provided for @settingsBillLead.
  ///
  /// In en, this message translates to:
  /// **'Remind before bills'**
  String get settingsBillLead;

  /// No description provided for @settingsNearby.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth sync (no Wi‑Fi)'**
  String get settingsNearby;

  /// No description provided for @settingsNearbyBody.
  ///
  /// In en, this message translates to:
  /// **'Find family phones nearby without Wi‑Fi, using Bluetooth and Wi‑Fi Direct.'**
  String get settingsNearbyBody;

  /// No description provided for @settingsPhoneName.
  ///
  /// In en, this message translates to:
  /// **'This phone\'s name'**
  String get settingsPhoneName;

  /// No description provided for @settingsPhoneNameBody.
  ///
  /// In en, this message translates to:
  /// **'Shown to family phones when they sync'**
  String get settingsPhoneNameBody;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get settingsData;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export as spreadsheet (CSV)'**
  String get exportCsv;

  /// No description provided for @exportJson.
  ///
  /// In en, this message translates to:
  /// **'Export as JSON'**
  String get exportJson;

  /// No description provided for @backupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create encrypted backup'**
  String get backupCreate;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get backupRestore;

  /// No description provided for @backupPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Backup passphrase'**
  String get backupPassphrase;

  /// No description provided for @backupPassphraseHint.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters. You\'ll need it to restore.'**
  String get backupPassphraseHint;

  /// No description provided for @backupWrongPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Wrong passphrase.'**
  String get backupWrongPassphrase;

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored {name}'**
  String backupRestored(String name);

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About FamBoard'**
  String get settingsAbout;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'Version {version}. Your board lives on your family\'s phones and syncs between them directly. No ads, no tracking.'**
  String aboutBody(String version);

  /// No description provided for @settingsNeedsRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart sync to apply'**
  String get settingsNeedsRestart;

  /// No description provided for @notifChannel.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get notifChannel;

  /// No description provided for @notifDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today: {title}'**
  String notifDueToday(String title);

  /// No description provided for @notifDueIn.
  ///
  /// In en, this message translates to:
  /// **'{title}: due in {days} days'**
  String notifDueIn(String title, int days);

  /// No description provided for @notifDigestTitle.
  ///
  /// In en, this message translates to:
  /// **'FamBoard today'**
  String get notifDigestTitle;

  /// No description provided for @notifDigestBody.
  ///
  /// In en, this message translates to:
  /// **'See what\'s due and what\'s needed today.'**
  String get notifDigestBody;

  /// No description provided for @pasteSmsTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a bill from a message'**
  String get pasteSmsTitle;

  /// No description provided for @pasteSmsHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the bill SMS here'**
  String get pasteSmsHint;

  /// No description provided for @smsFoundBill.
  ///
  /// In en, this message translates to:
  /// **'Found a bill'**
  String get smsFoundBill;

  /// No description provided for @noBillFound.
  ///
  /// In en, this message translates to:
  /// **'No bill found in that text. You can still add it as an item.'**
  String get noBillFound;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @categoryAdd.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get categoryAdd;

  /// No description provided for @categoryNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoryNameLabel;

  /// No description provided for @categoryParentLabel.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get categoryParentLabel;

  /// No description provided for @permissionsNeeded.
  ///
  /// In en, this message translates to:
  /// **'Allow Bluetooth and nearby-devices access to sync without Wi‑Fi.'**
  String get permissionsNeeded;

  /// No description provided for @genericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get genericError;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String minutesAgo(int n);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 hour ago} other{{n} hours ago}}'**
  String hoursAgo(int n);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{yesterday} other{{n} days ago}}'**
  String daysAgo(int n);

  /// No description provided for @syncFixTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync can\'t find other phones yet'**
  String get syncFixTitle;

  /// No description provided for @problemNearbyPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow “Nearby devices” so phones can find each other over Bluetooth.'**
  String get problemNearbyPermission;

  /// No description provided for @problemLocationPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow Location. Android needs it to scan for nearby phones.'**
  String get problemLocationPermission;

  /// No description provided for @problemLocationOff.
  ///
  /// In en, this message translates to:
  /// **'Turn on Location in quick settings. Bluetooth scanning finds nothing while it\'s off.'**
  String get problemLocationOff;

  /// No description provided for @problemBluetoothOff.
  ///
  /// In en, this message translates to:
  /// **'Turn on Bluetooth.'**
  String get problemBluetoothOff;

  /// No description provided for @problemNoWifi.
  ///
  /// In en, this message translates to:
  /// **'Connect both phones to the same Wi‑Fi, or use Bluetooth.'**
  String get problemNoWifi;

  /// No description provided for @allowPermissions.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allowPermissions;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @checkAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get checkAgain;

  /// No description provided for @syncDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Sync details'**
  String get syncDiagnostics;

  /// No description provided for @diagThisPhone.
  ///
  /// In en, this message translates to:
  /// **'This phone'**
  String get diagThisPhone;

  /// No description provided for @diagMethods.
  ///
  /// In en, this message translates to:
  /// **'Connection methods'**
  String get diagMethods;

  /// No description provided for @diagRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get diagRunning;

  /// No description provided for @diagNotRunning.
  ///
  /// In en, this message translates to:
  /// **'Not running'**
  String get diagNotRunning;

  /// No description provided for @diagPhonesSeen.
  ///
  /// In en, this message translates to:
  /// **'Phones seen now'**
  String get diagPhonesSeen;

  /// No description provided for @diagNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get diagNone;

  /// No description provided for @diagRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get diagRecent;

  /// No description provided for @diagLastError.
  ///
  /// In en, this message translates to:
  /// **'Last error'**
  String get diagLastError;

  /// No description provided for @diagCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy details'**
  String get diagCopy;

  /// No description provided for @diagHint.
  ///
  /// In en, this message translates to:
  /// **'Both phones need FamBoard open at the same time. Same Wi‑Fi works best; otherwise keep Bluetooth and Location on.'**
  String get diagHint;
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
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
