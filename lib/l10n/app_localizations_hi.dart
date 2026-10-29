// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'FamBoard';

  @override
  String get navToday => 'आज';

  @override
  String get navLists => 'सूचियाँ';

  @override
  String get navBills => 'बिल';

  @override
  String get navFamily => 'परिवार';

  @override
  String get save => 'सहेजें';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get delete => 'हटाएँ';

  @override
  String get restore => 'वापस लाएँ';

  @override
  String get edit => 'बदलें';

  @override
  String get close => 'बंद करें';

  @override
  String get add => 'जोड़ें';

  @override
  String get undo => 'पहले जैसा करें';

  @override
  String get search => 'खोजें';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get copy => 'कॉपी करें';

  @override
  String get copied => 'कॉपी हो गया';

  @override
  String get remove => 'हटाएँ';

  @override
  String get rename => 'नाम बदलें';

  @override
  String get change => 'बदलें';

  @override
  String get welcomeTitle => 'आपके घर का साझा बोर्ड';

  @override
  String get welcomeBody =>
      'क्या चाहिए, क्या ख़राब है और क्या भरना है, सब यहाँ लिखें। FamBoard परिवार के फ़ोनों के बीच Wi‑Fi या Bluetooth से सिंक होता है, इंटरनेट की ज़रूरत नहीं।';

  @override
  String get createFamily => 'नया परिवार बनाएँ';

  @override
  String get joinFamily => 'परिवार से जुड़ें';

  @override
  String get familyNameLabel => 'परिवार का नाम';

  @override
  String get familyNameHint => 'जैसे शर्मा परिवार';

  @override
  String get yourNameLabel => 'आपका नाम';

  @override
  String get yourNameHint => 'जैसे प्रिया';

  @override
  String get createFamilyAction => 'परिवार बनाएँ';

  @override
  String get scanInviteTitle => 'आमंत्रण QR स्कैन करें';

  @override
  String get scanInviteBody =>
      'परिवार के एडमिन से परिवार → किसी को आमंत्रित करें खोलने को कहें, फिर कैमरा कोड पर रखें।';

  @override
  String get pasteInvite => 'इसकी जगह आमंत्रण कोड पेस्ट करें';

  @override
  String get inviteCodeLabel => 'आमंत्रण कोड';

  @override
  String get joinAction => 'परिवार से जुड़ें';

  @override
  String get inviteExpired => 'यह आमंत्रण पुराना हो गया है। नया QR कोड माँगें।';

  @override
  String get inviteInvalid => 'यह FamBoard आमंत्रण नहीं है।';

  @override
  String joiningFamily(String name) {
    return '$name से जुड़ रहे हैं';
  }

  @override
  String get joinedWaitingSync =>
      'आप जुड़ गए! परिवार का बोर्ड पाने के लिए दोनों फ़ोन पास में खुले रखें।';

  @override
  String get cameraUnavailable =>
      'कैमरा उपलब्ध नहीं है। आमंत्रण कोड पेस्ट करें।';

  @override
  String get typeNeedToBuy => 'ख़रीदना है';

  @override
  String get typeOutOfStock => 'ख़त्म हो गया';

  @override
  String get typeRepair => 'मरम्मत';

  @override
  String get typeUpgrade => 'नया लेना है';

  @override
  String get typeBill => 'बिल';

  @override
  String get typeTask => 'काम';

  @override
  String get statusProposed => 'प्रस्तावित';

  @override
  String get statusOpen => 'बाक़ी';

  @override
  String get statusInProgress => 'चल रहा है';

  @override
  String get statusDone => 'हो गया';

  @override
  String get statusCancelled => 'रद्द';

  @override
  String get priorityLow => 'कम';

  @override
  String get priorityNormal => 'सामान्य';

  @override
  String get priorityHigh => 'ज़्यादा';

  @override
  String get priorityUrgent => 'तुरंत';

  @override
  String get roleAdmin => 'एडमिन';

  @override
  String get roleMember => 'सदस्य';

  @override
  String get roleChild => 'बच्चा';

  @override
  String get roleViewer => 'दर्शक';

  @override
  String get roleAdminDesc => 'सब कुछ कर सकते हैं, लोगों को जोड़ना और हटाना भी';

  @override
  String get roleMemberDesc =>
      'आइटम जोड़ते, बदलते और पूरे करते हैं; बिल की रक़म देखते हैं';

  @override
  String get roleChildDesc =>
      'आइटम जोड़ते और अपने पूरे करते हैं; रक़म छिपी रहती है';

  @override
  String get roleViewerDesc =>
      'सूचियाँ देखते और ख़रीदारी पर टिक लगाते हैं, जैसे घर में मदद करने वाले';

  @override
  String get todayOverdue => 'देर हो चुकी';

  @override
  String get todayDueToday => 'आज करना है';

  @override
  String get todayUrgentRepairs => 'ज़रूरी मरम्मत';

  @override
  String get todayOutOfStock => 'ख़त्म हो गया';

  @override
  String get todayMine => 'आपके ज़िम्मे';

  @override
  String get todayUpcoming => 'इस हफ़्ते आगे';

  @override
  String get todayAllClear => 'आज सब ठीक है';

  @override
  String get todayAllClearBody =>
      'आज कुछ भी बाक़ी या देर से नहीं है। कुछ जोड़ने के लिए + दबाएँ।';

  @override
  String shoppingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चीज़ें ख़रीदनी हैं',
      one: '1 चीज़ ख़रीदनी है',
    );
    return '$_temp0';
  }

  @override
  String get startShopping => 'ख़रीदारी शुरू करें';

  @override
  String get quickAddTitle => 'बोर्ड पर जोड़ें';

  @override
  String get quickAddHint => 'क्या चाहिए? जैसे आटा 10kg, नल टपक रहा है';

  @override
  String get moreDetails => 'और जानकारी';

  @override
  String get fewerDetails => 'कम जानकारी';

  @override
  String get categoryLabel => 'श्रेणी';

  @override
  String get typeLabel => 'प्रकार';

  @override
  String get priorityLabel => 'प्राथमिकता';

  @override
  String get quantityLabel => 'मात्रा';

  @override
  String get unitLabel => 'इकाई';

  @override
  String get amountLabel => 'रक़म (₹)';

  @override
  String get dueLabel => 'आख़िरी तारीख़';

  @override
  String get noDueDate => 'कोई तारीख़ नहीं';

  @override
  String get assigneeLabel => 'किसके ज़िम्मे';

  @override
  String get nobody => 'कोई नहीं';

  @override
  String get repeatLabel => 'दोहराएँ';

  @override
  String get repeatNever => 'नहीं दोहराना';

  @override
  String get repeatDaily => 'रोज़';

  @override
  String get repeatWeekly => 'हर हफ़्ते';

  @override
  String get repeatMonthly => 'हर महीने';

  @override
  String get repeatQuarterly => 'हर 3 महीने';

  @override
  String get repeatYearly => 'हर साल';

  @override
  String get repeatEveryNDays => 'कुछ दिनों में';

  @override
  String everyNDays(int n) {
    return 'हर $n दिन';
  }

  @override
  String everyNMonths(int n) {
    return 'हर $n महीने';
  }

  @override
  String everyNWeeks(int n) {
    return 'हर $n हफ़्ते';
  }

  @override
  String monthlyOnDay(int day) {
    return 'हर महीने की $day तारीख़';
  }

  @override
  String weeklyOn(String day) {
    return 'हर हफ़्ते $day को';
  }

  @override
  String get daysLabel => 'दिन';

  @override
  String get reminderLabel => 'पहले याद दिलाएँ';

  @override
  String get reminderNone => 'सिर्फ़ उसी दिन';

  @override
  String reminderDaysBefore(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n दिन पहले',
      one: '1 दिन पहले',
    );
    return '$_temp0';
  }

  @override
  String get noteLabel => 'नोट';

  @override
  String duplicateWarning(String title) {
    return 'बोर्ड पर पहले से है: “$title”';
  }

  @override
  String get viewExisting => 'देखें';

  @override
  String get entryAdded => 'बोर्ड पर जुड़ गया';

  @override
  String get voiceListening => 'सुन रहे हैं…';

  @override
  String get voiceNeedsInternet =>
      'यहाँ आवाज़ के लिए इंटरनेट चाहिए। फ़ोन की सेटिंग्स में इस भाषा का ऑफ़लाइन स्पीच पैक डाउनलोड करें, या टाइप करें।';

  @override
  String get voiceUnavailable =>
      'इस फ़ोन पर आवाज़ से लिखना उपलब्ध नहीं है। आप टाइप कर सकते हैं।';

  @override
  String get voicePermission =>
      'आवाज़ से जोड़ने के लिए माइक्रोफ़ोन की अनुमति दें।';

  @override
  String get voiceNoMatch => 'समझ नहीं आया। फिर से बोलें।';

  @override
  String get voiceEnglish => 'English';

  @override
  String get voiceHindi => 'हिन्दी';

  @override
  String get learnedCategory => 'ठीक है। FamBoard यह श्रेणी याद रखेगा।';

  @override
  String get markDone => 'पूरा हुआ';

  @override
  String get markBought => 'ख़रीद लिया';

  @override
  String get markPaid => 'भर दिया';

  @override
  String get startWork => 'शुरू करें';

  @override
  String get reopen => 'फिर से खोलें';

  @override
  String get cancelEntry => 'रद्द करें';

  @override
  String get claim => 'मैं करूँगा/करूँगी';

  @override
  String get unclaim => 'छोड़ दें';

  @override
  String claimedBy(String name) {
    return '$name कर रहे हैं';
  }

  @override
  String get historyTitle => 'इतिहास';

  @override
  String activityCreated(String name) {
    return '$name ने जोड़ा';
  }

  @override
  String activityCreatedRecurring(String name) {
    return '$name ने पिछला पूरा किया; यह अगला है';
  }

  @override
  String activityEdited(String name) {
    return '$name ने बदला';
  }

  @override
  String activityClaimed(String name) {
    return '$name ने ज़िम्मा लिया';
  }

  @override
  String activityUnclaimed(String name) {
    return '$name ने छोड़ दिया';
  }

  @override
  String activityStatus(String name, String status) {
    return '$name ने $status किया';
  }

  @override
  String activityDeleted(String name) {
    return '$name ने हटाया';
  }

  @override
  String activityRestored(String name) {
    return '$name ने वापस लाया';
  }

  @override
  String activityBought(String name) {
    return '$name ने ख़रीदा';
  }

  @override
  String get deleteConfirmTitle => 'यह आइटम हटाएँ?';

  @override
  String get deleteConfirmBody =>
      'आप इसे सूचियाँ → हटाए गए से वापस ला सकते हैं।';

  @override
  String get entryDeleted => 'हटा दिया';

  @override
  String nextOccurrence(String date) {
    return 'अगला $date के लिए जोड़ा गया';
  }

  @override
  String dueOn(String date) {
    return '$date तक';
  }

  @override
  String overdueBy(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days दिन देर',
      one: '1 दिन देर',
    );
    return '$_temp0';
  }

  @override
  String get dueTodayShort => 'आज तक';

  @override
  String get dueTomorrow => 'कल तक';

  @override
  String addedBy(String name) {
    return '$name ने जोड़ा';
  }

  @override
  String get someone => 'कोई';

  @override
  String get deletedBadge => 'हटाया गया';

  @override
  String get notFound => 'यह आइटम अब बोर्ड पर नहीं है।';

  @override
  String get listsAllOpen => 'सभी बाक़ी';

  @override
  String get listsDaily => 'रोज़ाना';

  @override
  String get listsWeekly => 'साप्ताहिक';

  @override
  String get listsMonthly => 'मासिक';

  @override
  String get listsYearly => 'सालाना';

  @override
  String get listsRecurring => 'दोहराने वाले';

  @override
  String get listsDone => 'पूरे हुए';

  @override
  String get listsDeleted => 'हटाए गए';

  @override
  String get listsEmpty => 'यहाँ कुछ नहीं है';

  @override
  String get filters => 'फ़िल्टर';

  @override
  String get filterAll => 'सभी';

  @override
  String get clearFilters => 'फ़िल्टर हटाएँ';

  @override
  String get searchHint => 'बोर्ड में खोजें';

  @override
  String get noResults => 'कुछ नहीं मिला';

  @override
  String get billsStillToPay => 'इस महीने भरना बाक़ी';

  @override
  String get billsPaidThisMonth => 'इस महीने भरा';

  @override
  String get billsUpcoming => 'आने वाले बिल';

  @override
  String get billsPaid => 'हाल में भरे';

  @override
  String get billsEmpty => 'अभी कोई बिल नहीं';

  @override
  String get billsEmptyBody =>
      '“बिजली बिल 1200 10 तारीख़ तक” जैसा बिल जोड़ें, उसे हर महीने दोहराएँ, और FamBoard याद दिलाएगा।';

  @override
  String get billsAmountsHidden => 'बिल की रक़म सिर्फ़ बड़ों को दिखती है।';

  @override
  String get addFromSms => 'बिल SMS से जोड़ें';

  @override
  String get amountHidden => 'छिपा है';

  @override
  String get shoppingTitle => 'ख़रीदारी';

  @override
  String get shoppingEmpty => 'कुछ नहीं ख़रीदना। बढ़िया!';

  @override
  String get shoppingHelp => 'कार्ट में डालते ही आइटम पर टैप करें।';

  @override
  String shoppingBought(String title) {
    return '$title ख़रीद लिया';
  }

  @override
  String get familyMembers => 'सदस्य';

  @override
  String get inviteSomeone => 'किसी को आमंत्रित करें';

  @override
  String inviteTitle(String family) {
    return '$family में आमंत्रित करें';
  }

  @override
  String get inviteJoinAs => 'किस रूप में जुड़ेंगे';

  @override
  String get inviteInstructions =>
      'दूसरे फ़ोन पर FamBoard खोलें, “परिवार से जुड़ें” चुनें और यह कोड स्कैन करें। इसे सिर्फ़ आमने-सामने दिखाएँ: जिसके पास यह कोड है, वह जुड़ सकता है।';

  @override
  String inviteExpiresIn(String time) {
    return '$time में ख़त्म';
  }

  @override
  String get inviteExpiredTitle => 'यह कोड पुराना हो गया है';

  @override
  String get inviteNewCode => 'नया कोड';

  @override
  String get inviteCopyCode => 'कोड कॉपी करें';

  @override
  String get removeMember => 'परिवार से हटाएँ';

  @override
  String removeMemberConfirm(String name) {
    return '$name को हटाएँ? उनके फ़ोन आपके साथ सिंक होना बंद कर देंगे।';
  }

  @override
  String get changeRole => 'भूमिका बदलें';

  @override
  String get youLabel => 'आप';

  @override
  String get removedLabel => 'हटाए गए';

  @override
  String get syncTitle => 'सिंक';

  @override
  String get familyPhones => 'परिवार के फ़ोन';

  @override
  String get noPhonesYet =>
      'अभी कोई फ़ोन नहीं दिखा। दोनों फ़ोन पर FamBoard खुला रखें, एक ही Wi‑Fi पर या Bluetooth चालू करके।';

  @override
  String phoneLastSynced(String time, String via) {
    return '$time $via से सिंक हुआ';
  }

  @override
  String phoneSeen(String time) {
    return '$time दिखा';
  }

  @override
  String get nearbyNow => 'अभी पास में';

  @override
  String get syncNow => 'अभी सिंक करें';

  @override
  String get syncing => 'सिंक हो रहा है…';

  @override
  String get syncNever => 'अभी तक सिंक नहीं हुआ';

  @override
  String syncedWith(String name, String time) {
    return '$name के साथ सिंक · $time';
  }

  @override
  String syncStale(int days) {
    return '$days दिन से सिंक नहीं हुआ';
  }

  @override
  String get syncSearching => 'परिवार के फ़ोन ढूँढ रहे हैं…';

  @override
  String syncPeersNearby(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'परिवार के $count फ़ोन पास में',
      one: 'परिवार का 1 फ़ोन पास में',
    );
    return '$_temp0';
  }

  @override
  String get syncOff => 'सिंक बंद है';

  @override
  String get viaWifi => 'Wi‑Fi';

  @override
  String get viaNearby => 'Bluetooth';

  @override
  String get viaOther => 'सीधे';

  @override
  String syncReceived(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name से $count अपडेट',
      one: '$name से 1 अपडेट',
    );
    return '$_temp0';
  }

  @override
  String get syncNoPeersToSync => 'अभी परिवार का कोई फ़ोन पास में नहीं है।';

  @override
  String get renameFamily => 'परिवार का नाम बदलें';

  @override
  String get switchFamily => 'परिवार बदलें';

  @override
  String get addAnotherFamily => 'दूसरा परिवार बनाएँ या जुड़ें';

  @override
  String get settingsLanguage => 'भाषा';

  @override
  String get languageSystem => 'फ़ोन की भाषा';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'हिन्दी';

  @override
  String get settingsLargeText => 'बड़े अक्षर';

  @override
  String get settingsLargeTextBody => 'बड़े अक्षर और बटन, पढ़ने में आसान';

  @override
  String get settingsReminders => 'रिमाइंडर';

  @override
  String get settingsNotifications => 'सूचनाएँ';

  @override
  String get settingsDigestTime => 'रोज़ का सारांश';

  @override
  String get settingsBillLead => 'बिल से पहले याद दिलाएँ';

  @override
  String get settingsNearby => 'Bluetooth सिंक (बिना Wi‑Fi)';

  @override
  String get settingsNearbyBody =>
      'बिना Wi‑Fi के पास के फ़ोन ढूँढें, Bluetooth और Wi‑Fi Direct से।';

  @override
  String get settingsPhoneName => 'इस फ़ोन का नाम';

  @override
  String get settingsPhoneNameBody =>
      'सिंक करते समय परिवार के फ़ोनों को दिखता है';

  @override
  String get settingsData => 'आपका डेटा';

  @override
  String get exportCsv => 'स्प्रेडशीट (CSV) में निर्यात करें';

  @override
  String get exportJson => 'JSON में निर्यात करें';

  @override
  String get backupCreate => 'एन्क्रिप्टेड बैकअप बनाएँ';

  @override
  String get backupRestore => 'बैकअप से वापस लाएँ';

  @override
  String get backupPassphrase => 'बैकअप पासफ़्रेज़';

  @override
  String get backupPassphraseHint =>
      'कम से कम 6 अक्षर। वापस लाने के लिए यह चाहिए होगा।';

  @override
  String get backupWrongPassphrase => 'पासफ़्रेज़ ग़लत है।';

  @override
  String backupRestored(String name) {
    return '$name वापस आ गया';
  }

  @override
  String get settingsAbout => 'FamBoard के बारे में';

  @override
  String aboutBody(String version) {
    return 'संस्करण $version। आपका बोर्ड परिवार के फ़ोनों पर रहता है और सीधे उनके बीच सिंक होता है। कोई विज्ञापन नहीं, कोई ट्रैकिंग नहीं।';
  }

  @override
  String get settingsNeedsRestart => 'लागू करने के लिए सिंक फिर से शुरू करें';

  @override
  String get notifChannel => 'रिमाइंडर';

  @override
  String notifDueToday(String title) {
    return 'आज तक: $title';
  }

  @override
  String notifDueIn(String title, int days) {
    return '$title: $days दिन में';
  }

  @override
  String get notifDigestTitle => 'FamBoard आज';

  @override
  String get notifDigestBody => 'देखें आज क्या भरना है और क्या चाहिए।';

  @override
  String get pasteSmsTitle => 'मैसेज से बिल जोड़ें';

  @override
  String get pasteSmsHint => 'बिल का SMS यहाँ पेस्ट करें';

  @override
  String get smsFoundBill => 'बिल मिला';

  @override
  String get noBillFound =>
      'इस मैसेज में बिल नहीं मिला। आप फिर भी इसे आइटम की तरह जोड़ सकते हैं।';

  @override
  String get continueAction => 'आगे बढ़ें';

  @override
  String get categoryAdd => 'नई श्रेणी';

  @override
  String get categoryNameLabel => 'श्रेणी का नाम';

  @override
  String get categoryParentLabel => 'समूह';

  @override
  String get permissionsNeeded =>
      'बिना Wi‑Fi सिंक के लिए Bluetooth और पास के डिवाइस की अनुमति दें।';

  @override
  String get genericError => 'कुछ ग़लत हो गया। फिर से कोशिश करें।';

  @override
  String get justNow => 'अभी';

  @override
  String minutesAgo(int n) {
    return '$n मिनट पहले';
  }

  @override
  String hoursAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n घंटे पहले',
      one: '1 घंटा पहले',
    );
    return '$_temp0';
  }

  @override
  String daysAgo(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n दिन पहले',
      one: 'कल',
    );
    return '$_temp0';
  }
}
