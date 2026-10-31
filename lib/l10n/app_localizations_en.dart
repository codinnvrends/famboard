// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FamBoard';

  @override
  String get navToday => 'Today';

  @override
  String get navLists => 'Lists';

  @override
  String get navBills => 'Bills';

  @override
  String get navFamily => 'Family';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get restore => 'Restore';

  @override
  String get edit => 'Edit';

  @override
  String get close => 'Close';

  @override
  String get add => 'Add';

  @override
  String get undo => 'Undo';

  @override
  String get search => 'Search';

  @override
  String get settings => 'Settings';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get remove => 'Remove';

  @override
  String get rename => 'Rename';

  @override
  String get change => 'Change';

  @override
  String get welcomeTitle => 'Your home\'s shared board';

  @override
  String get welcomeBody =>
      'Note what\'s needed, what\'s broken and what\'s due. FamBoard syncs between family phones over Wi‑Fi or Bluetooth, with no internet needed.';

  @override
  String get createFamily => 'Create a family';

  @override
  String get joinFamily => 'Join a family';

  @override
  String get familyNameLabel => 'Family name';

  @override
  String get familyNameHint => 'e.g. Sharma home';

  @override
  String get yourNameLabel => 'Your name';

  @override
  String get yourNameHint => 'e.g. Priya';

  @override
  String get createFamilyAction => 'Create family';

  @override
  String get scanInviteTitle => 'Scan the invite QR';

  @override
  String get scanInviteBody =>
      'Ask anyone grown-up in the family to open Family → Invite someone, then point your camera at the code.';

  @override
  String get pasteInvite => 'Paste invite code instead';

  @override
  String get inviteCodeLabel => 'Invite code';

  @override
  String get joinAction => 'Join family';

  @override
  String get inviteExpired => 'This invite has expired. Ask for a new QR code.';

  @override
  String get inviteInvalid => 'That is not a FamBoard invite.';

  @override
  String joiningFamily(String name) {
    return 'Joining $name';
  }

  @override
  String get joinedWaitingSync =>
      'You\'re in! Keep both phones open nearby to get the family\'s board.';

  @override
  String get cameraUnavailable =>
      'Camera not available. Paste the invite code instead.';

  @override
  String get typeNeedToBuy => 'Need to buy';

  @override
  String get typeOutOfStock => 'Out of stock';

  @override
  String get typeRepair => 'Repair';

  @override
  String get typeUpgrade => 'Upgrade';

  @override
  String get typeBill => 'Bill';

  @override
  String get typeTask => 'Task';

  @override
  String get statusProposed => 'Proposed';

  @override
  String get statusOpen => 'Open';

  @override
  String get statusInProgress => 'In progress';

  @override
  String get statusDone => 'Done';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityNormal => 'Normal';

  @override
  String get priorityHigh => 'High';

  @override
  String get priorityUrgent => 'Urgent';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleMember => 'Member';

  @override
  String get roleChild => 'Child';

  @override
  String get roleViewer => 'Viewer';

  @override
  String get roleAdminDesc =>
      'Can do everything, including inviting and removing people';

  @override
  String get roleMemberDesc =>
      'Adds, edits and completes items; sees bill amounts';

  @override
  String get roleChildDesc =>
      'Adds items and completes their own; amounts hidden';

  @override
  String get roleViewerDesc =>
      'Sees lists and ticks off shopping, e.g. a helper';

  @override
  String get todayOverdue => 'Overdue';

  @override
  String get todayDueToday => 'Due today';

  @override
  String get todayUrgentRepairs => 'Urgent repairs';

  @override
  String get todayOutOfStock => 'Out of stock';

  @override
  String get todayMine => 'You\'re on it';

  @override
  String get todayUpcoming => 'Coming up this week';

  @override
  String get todayAllClear => 'All clear for today';

  @override
  String get todayAllClearBody =>
      'Nothing is overdue or due today. Tap + to add something.';

  @override
  String shoppingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items to buy',
      one: '1 item to buy',
    );
    return '$_temp0';
  }

  @override
  String get startShopping => 'Start shopping';

  @override
  String get quickAddTitle => 'Add to the board';

  @override
  String get quickAddHint => 'What\'s needed? e.g. atta 10kg, tap leaking';

  @override
  String get moreDetails => 'More details';

  @override
  String get fewerDetails => 'Fewer details';

  @override
  String get categoryLabel => 'Category';

  @override
  String get typeLabel => 'Type';

  @override
  String get priorityLabel => 'Priority';

  @override
  String get quantityLabel => 'Quantity';

  @override
  String get unitLabel => 'Unit';

  @override
  String get amountLabel => 'Amount (₹)';

  @override
  String get dueLabel => 'Due date';

  @override
  String get noDueDate => 'No due date';

  @override
  String get assigneeLabel => 'Assigned to';

  @override
  String get nobody => 'Nobody';

  @override
  String get repeatLabel => 'Repeats';

  @override
  String get repeatNever => 'Doesn\'t repeat';

  @override
  String get repeatDaily => 'Every day';

  @override
  String get repeatWeekly => 'Every week';

  @override
  String get repeatMonthly => 'Every month';

  @override
  String get repeatQuarterly => 'Every 3 months';

  @override
  String get repeatYearly => 'Every year';

  @override
  String get repeatEveryNDays => 'Every few days';

  @override
  String everyNDays(int n) {
    return 'Every $n days';
  }

  @override
  String everyNMonths(int n) {
    return 'Every $n months';
  }

  @override
  String everyNWeeks(int n) {
    return 'Every $n weeks';
  }

  @override
  String monthlyOnDay(int day) {
    return 'Monthly on day $day';
  }

  @override
  String weeklyOn(String day) {
    return 'Weekly on $day';
  }

  @override
  String get daysLabel => 'Days';

  @override
  String get reminderLabel => 'Remind early';

  @override
  String get reminderNone => 'Only on the due date';

  @override
  String reminderDaysBefore(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days before',
      one: '1 day before',
    );
    return '$_temp0';
  }

  @override
  String get noteLabel => 'Note';

  @override
  String duplicateWarning(String title) {
    return 'Already on the board: “$title”';
  }

  @override
  String get viewExisting => 'View';

  @override
  String get entryAdded => 'Added to the board';

  @override
  String get voiceListening => 'Listening…';

  @override
  String get voiceNeedsInternet =>
      'Voice needs internet here. Download the offline speech pack for this language in your phone\'s settings, or type instead.';

  @override
  String get voiceUnavailable =>
      'Voice input isn\'t available on this phone. You can type instead.';

  @override
  String get voicePermission => 'Allow microphone access to use voice entry.';

  @override
  String get voiceNoMatch => 'Didn\'t catch that. Try again.';

  @override
  String get voiceEnglish => 'English';

  @override
  String get voiceHindi => 'हिन्दी';

  @override
  String get learnedCategory => 'Got it. FamBoard will remember this category.';

  @override
  String get markDone => 'Mark done';

  @override
  String get markBought => 'Bought';

  @override
  String get markPaid => 'Mark paid';

  @override
  String get startWork => 'Start';

  @override
  String get reopen => 'Reopen';

  @override
  String get cancelEntry => 'Cancel item';

  @override
  String get claim => 'I\'ll do it';

  @override
  String get unclaim => 'Let go';

  @override
  String claimedBy(String name) {
    return '$name is on it';
  }

  @override
  String get historyTitle => 'History';

  @override
  String activityCreated(String name) {
    return '$name added this';
  }

  @override
  String activityCreatedRecurring(String name) {
    return '$name completed the last one; this is the next';
  }

  @override
  String activityEdited(String name) {
    return '$name edited it';
  }

  @override
  String activityClaimed(String name) {
    return '$name took it on';
  }

  @override
  String activityUnclaimed(String name) {
    return '$name let it go';
  }

  @override
  String activityStatus(String name, String status) {
    return '$name marked it $status';
  }

  @override
  String activityDeleted(String name) {
    return '$name deleted it';
  }

  @override
  String activityRestored(String name) {
    return '$name restored it';
  }

  @override
  String activityBought(String name) {
    return '$name bought it';
  }

  @override
  String get deleteConfirmTitle => 'Delete this item?';

  @override
  String get deleteConfirmBody => 'You can restore it from Lists → Deleted.';

  @override
  String get entryDeleted => 'Deleted';

  @override
  String nextOccurrence(String date) {
    return 'Next one added for $date';
  }

  @override
  String dueOn(String date) {
    return 'Due $date';
  }

  @override
  String overdueBy(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days overdue',
      one: '1 day overdue',
    );
    return '$_temp0';
  }

  @override
  String get dueTodayShort => 'Due today';

  @override
  String get dueTomorrow => 'Due tomorrow';

  @override
  String addedBy(String name) {
    return 'Added by $name';
  }

  @override
  String get someone => 'Someone';

  @override
  String get deletedBadge => 'Deleted';

  @override
  String get notFound => 'This item is no longer on the board.';

  @override
  String get listsAllOpen => 'All open';

  @override
  String get listsDaily => 'Daily';

  @override
  String get listsWeekly => 'Weekly';

  @override
  String get listsMonthly => 'Monthly';

  @override
  String get listsYearly => 'Yearly';

  @override
  String get listsRecurring => 'Recurring';

  @override
  String get listsDone => 'Done';

  @override
  String get listsDeleted => 'Deleted';

  @override
  String get listsEmpty => 'Nothing here';

  @override
  String get filters => 'Filters';

  @override
  String get filterAll => 'All';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get searchHint => 'Search the board';

  @override
  String get noResults => 'No matches';

  @override
  String get billsStillToPay => 'Still to pay this month';

  @override
  String get billsPaidThisMonth => 'Paid this month';

  @override
  String get billsUpcoming => 'Upcoming bills';

  @override
  String get billsPaid => 'Paid recently';

  @override
  String get billsEmpty => 'No bills yet';

  @override
  String get billsEmptyBody =>
      'Add one like “electricity bill 1200 by 10th”, set it to repeat monthly, and FamBoard will remind you.';

  @override
  String get billsAmountsHidden => 'Bill amounts are visible to adults only.';

  @override
  String get addFromSms => 'Add from a bill SMS';

  @override
  String get amountHidden => 'Hidden';

  @override
  String get shoppingTitle => 'Shopping';

  @override
  String get shoppingEmpty => 'Nothing to buy. Nice!';

  @override
  String get shoppingHelp => 'Tap an item once it\'s in your cart.';

  @override
  String shoppingBought(String title) {
    return 'Bought $title';
  }

  @override
  String get familyMembers => 'Members';

  @override
  String get inviteSomeone => 'Invite someone';

  @override
  String inviteTitle(String family) {
    return 'Invite to $family';
  }

  @override
  String get inviteJoinAs => 'They join as';

  @override
  String get inviteInstructions =>
      'On the other phone, open FamBoard, choose “Join a family” and scan this code. Show it only in person: anyone with it can join.';

  @override
  String inviteExpiresIn(String time) {
    return 'Expires in $time';
  }

  @override
  String get inviteExpiredTitle => 'This code has expired';

  @override
  String get inviteNewCode => 'New code';

  @override
  String get inviteCopyCode => 'Copy code';

  @override
  String get removeMember => 'Remove from family';

  @override
  String removeMemberConfirm(String name) {
    return 'Remove $name? Their phones will stop syncing with yours.';
  }

  @override
  String get changeRole => 'Change role';

  @override
  String get youLabel => 'You';

  @override
  String get removedLabel => 'Removed';

  @override
  String get syncTitle => 'Sync';

  @override
  String get familyPhones => 'Family phones';

  @override
  String get noPhonesYet =>
      'No family phones seen yet. Keep FamBoard open on both phones, on the same Wi‑Fi or with Bluetooth on.';

  @override
  String phoneLastSynced(String time, String via) {
    return 'Synced $time via $via';
  }

  @override
  String phoneSeen(String time) {
    return 'Seen $time';
  }

  @override
  String get nearbyNow => 'Nearby now';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncing => 'Syncing…';

  @override
  String get syncNever => 'Not synced yet';

  @override
  String syncedWith(String name, String time) {
    return 'Synced with $name · $time';
  }

  @override
  String syncStale(int days) {
    return 'Not synced for $days days';
  }

  @override
  String get syncSearching => 'Looking for family phones…';

  @override
  String syncPeersNearby(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count family phones nearby',
      one: '1 family phone nearby',
    );
    return '$_temp0';
  }

  @override
  String get syncOff => 'Sync is off';

  @override
  String get viaWifi => 'Wi‑Fi';

  @override
  String get viaNearby => 'Bluetooth';

  @override
  String get viaOther => 'direct';

  @override
  String syncReceived(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count updates from $name',
      one: '1 update from $name',
    );
    return '$_temp0';
  }

  @override
  String get syncNoPeersToSync => 'No family phones nearby right now.';

  @override
  String get renameFamily => 'Rename family';

  @override
  String get switchFamily => 'Switch family';

  @override
  String get addAnotherFamily => 'Create or join another family';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'Phone default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'हिन्दी (Hindi)';

  @override
  String get settingsLargeText => 'Large text';

  @override
  String get settingsLargeTextBody => 'Bigger text and buttons, easier to read';

  @override
  String get settingsReminders => 'Reminders';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsDigestTime => 'Daily summary';

  @override
  String get settingsBillLead => 'Remind before bills';

  @override
  String get settingsNearby => 'Bluetooth sync (no Wi‑Fi)';

  @override
  String get settingsNearbyBody =>
      'Find family phones nearby without Wi‑Fi, using Bluetooth and Wi‑Fi Direct.';

  @override
  String get settingsPhoneName => 'This phone\'s name';

  @override
  String get settingsPhoneNameBody => 'Shown to family phones when they sync';

  @override
  String get settingsData => 'Your data';

  @override
  String get exportCsv => 'Export as spreadsheet (CSV)';

  @override
  String get exportJson => 'Export as JSON';

  @override
  String get backupCreate => 'Create encrypted backup';

  @override
  String get backupRestore => 'Restore from backup';

  @override
  String get backupPassphrase => 'Backup passphrase';

  @override
  String get backupPassphraseHint =>
      'At least 6 characters. Without it the backup can\'t be opened, so write it down.';

  @override
  String get backupWrongPassphrase => 'Wrong passphrase.';

  @override
  String backupRestored(String name) {
    return 'Restored $name';
  }

  @override
  String get settingsAbout => 'About FamBoard';

  @override
  String aboutBody(String version) {
    return 'Version $version. Your board lives on your family\'s phones and syncs between them directly. No ads, no tracking.';
  }

  @override
  String get settingsNeedsRestart => 'Restart sync to apply';

  @override
  String get notifChannel => 'Reminders';

  @override
  String notifDueToday(String title) {
    return 'Due today: $title';
  }

  @override
  String notifDueIn(String title, int days) {
    return '$title: due in $days days';
  }

  @override
  String get notifDigestTitle => 'FamBoard today';

  @override
  String get notifDigestBody => 'See what\'s due and what\'s needed today.';

  @override
  String get pasteSmsTitle => 'Add a bill from a message';

  @override
  String get pasteSmsHint => 'Paste the bill SMS here';

  @override
  String get smsFoundBill => 'Found a bill';

  @override
  String get noBillFound =>
      'No bill found in that text. You can still add it as an item.';

  @override
  String get continueAction => 'Continue';

  @override
  String get categoryAdd => 'New category';

  @override
  String get categoryNameLabel => 'Category name';

  @override
  String get categoryParentLabel => 'Group';

  @override
  String get permissionsNeeded =>
      'Allow Bluetooth and nearby-devices access to sync without Wi‑Fi.';

  @override
  String get genericError => 'Something went wrong. Please try again.';

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int n) {
    return '$n min ago';
  }

  @override
  String hoursAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days ago',
      one: 'yesterday',
    );
    return '$_temp0';
  }

  @override
  String get syncFixTitle => 'Sync can\'t find other phones yet';

  @override
  String get problemNearbyPermission =>
      'Allow “Nearby devices” so phones can find each other over Bluetooth.';

  @override
  String get problemLocationPermission =>
      'Allow Location. Android needs it to scan for nearby phones.';

  @override
  String get problemLocationOff =>
      'Turn on Location in quick settings. Bluetooth scanning finds nothing while it\'s off.';

  @override
  String get problemBluetoothOff => 'Turn on Bluetooth.';

  @override
  String get problemNoWifi =>
      'Connect both phones to the same Wi‑Fi, or use Bluetooth.';

  @override
  String get allowPermissions => 'Allow';

  @override
  String get openSettings => 'Open settings';

  @override
  String get checkAgain => 'Check again';

  @override
  String get syncDiagnostics => 'Sync details';

  @override
  String get diagThisPhone => 'This phone';

  @override
  String get diagMethods => 'Connection methods';

  @override
  String get diagRunning => 'Running';

  @override
  String get diagNotRunning => 'Not running';

  @override
  String get diagPhonesSeen => 'Phones seen now';

  @override
  String get diagNone => 'None';

  @override
  String get diagRecent => 'Recent activity';

  @override
  String get diagLastError => 'Last error';

  @override
  String get diagCopy => 'Copy details';

  @override
  String get diagHint =>
      'Both phones need FamBoard open at the same time. Same Wi‑Fi works best; otherwise keep Bluetooth and Location on.';

  @override
  String get inviteNewPerson => 'New person';

  @override
  String get inviteReturning => 'Coming back';

  @override
  String get inviteReturningBody =>
      'For someone already in the family who reinstalled FamBoard or got a new phone. They get their name, role and history back.';

  @override
  String get inviteNoOneToBringBack => 'No other members yet.';

  @override
  String inviteReturningFor(String name, String role) {
    return 'Bringing back $name as $role';
  }

  @override
  String welcomeBack(String name, String family) {
    return 'Welcome back, $name, to $family';
  }

  @override
  String get welcomeBackBody =>
      'Your name, role and history come back after the first sync.';

  @override
  String get backupPassphraseAgain => 'Type it again';

  @override
  String get backupPassphraseMismatch => 'The two passphrases don\'t match.';

  @override
  String get backupReady => 'Backup ready';

  @override
  String get backupReadyBody =>
      'Save it somewhere that survives uninstalling FamBoard, like Downloads or Google Drive, or send it to yourself on WhatsApp.';

  @override
  String get backupSaveToPhone => 'Save to phone';

  @override
  String get backupSaved => 'Backup saved';

  @override
  String get backupShare => 'Share (WhatsApp, email, Drive…)';

  @override
  String get backupShareText =>
      'FamBoard backup. To restore: open this file with FamBoard, or FamBoard → Settings → Restore from backup.';

  @override
  String get backupNotABackup => 'That file isn\'t a FamBoard backup.';

  @override
  String get backupNever => 'No backup yet';

  @override
  String backupLast(String date) {
    return 'Last backup $date';
  }
}
