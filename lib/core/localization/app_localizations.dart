import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Small, dependency-free app translation catalog.
///
/// The language preference is stored by the onboarding store. Keeping the
/// catalog in one place means screens can switch language immediately without
/// duplicating locale checks throughout the UI.
class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static const supportedLocales = <Locale>[Locale('bn'), Locale('en')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final value = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return value ?? const AppLocalizations(Locale('bn'));
  }

  static AppLocalizations forLocale(Locale locale) => AppLocalizations(locale);

  bool get isBangla => locale.languageCode == 'bn';

  String get appTitle => isBangla ? 'এগ্রিগার্ডিয়ান' : 'AgriGuardian';
  String get home => isBangla ? 'হোম' : 'Home';
  String get myFields => isBangla ? 'আমার জমি' : 'My Fields';
  String get scan => isBangla ? 'স্ক্যান' : 'Scan';
  String get insights => isBangla ? 'ইনসাইট' : 'Insights';
  String get profile => isBangla ? 'প্রোফাইল' : 'Profile';

  String get language => isBangla ? 'ভাষা' : 'Language';
  String get chooseLanguage => isBangla ? 'ভাষা বেছে নিন' : 'Choose language';
  String get bangla => 'বাংলা';
  String get english => 'English';
  String get notifications => isBangla ? 'নোটিফিকেশন' : 'Notifications';
  String get notificationsOn => isBangla ? 'চালু' : 'On';
  String get farmLocation => isBangla ? 'খামারের অবস্থান' : 'Farm Location';
  String get bangladesh => isBangla ? 'বাংলাদেশ' : 'Bangladesh';
  String get irrigationSettings =>
      isBangla ? 'সেচের সেটিংস' : 'Irrigation Settings';
  String get farmSettings => isBangla ? 'খামারের সেটিংস' : 'Farm Settings';
  String get marketplace => isBangla ? 'মার্কেটপ্লেস' : 'Marketplace';
  String get sellOnMarketplace =>
      isBangla ? 'মার্কেটপ্লেসে বিক্রি করুন' : 'Sell on marketplace';
  String get scanHistory => isBangla ? 'স্ক্যানের ইতিহাস' : 'Scan History';
  String get helpSupport => isBangla ? 'সহায়তা ও সাপোর্ট' : 'Help & Support';
  String get privacyData => isBangla ? 'গোপনীয়তা ও ডেটা' : 'Privacy & Data';
  String get aboutApp =>
      isBangla ? 'AgriGuardian সম্পর্কে' : 'About AgriGuardian';
  String get activeUser => isBangla ? 'সক্রিয় ব্যবহারকারী' : 'Active User';
  String get acres => isBangla ? 'একর' : 'Acres';
  String get averageHealth => isBangla ? 'গড় স্বাস্থ্য' : 'Avg Health';
  String get scans => isBangla ? 'স্ক্যান' : 'Scans';
  String get logOut => isBangla ? 'লগ আউট' : 'Log out';

  String fieldCount(int count) {
    if (isBangla) return '${digits(count)}টি জমি';
    return '$count ${count == 1 ? 'Field' : 'Fields'}';
  }

  String stepOf(int step, int total) =>
      isBangla ? 'ধাপ $step / $total' : 'Step $step / $total';

  String get previousStep => isBangla ? 'আগের ধাপ' : 'Previous step';
  String get nextStep => isBangla ? 'পরবর্তী ধাপ' : 'Next step';

  // ---- Locale-aware number / date formatting ----
  static const _bnDigitChars = [
    '০',
    '১',
    '২',
    '৩',
    '৪',
    '৫',
    '৬',
    '৭',
    '৮',
    '৯',
  ];

  /// Digits in the active language: Bangla numerals for `bn`, ASCII for `en`.
  String digits(Object value) {
    final text = value.toString();
    if (!isBangla) return text;
    return text.replaceAllMapped(
      RegExp('[0-9]'),
      (m) => _bnDigitChars[int.parse(m[0]!)],
    );
  }

  String temperature(double celsius) => '${digits(celsius.round())}°';

  String dayMonth(int day, int month) => '${digits(day)}/${digits(month)}';

  String clockTime(DateTime time) =>
      '${digits(time.hour.toString().padLeft(2, '0'))}:'
      '${digits(time.minute.toString().padLeft(2, '0'))}';

  static const _bnWeekdayNames = [
    'সোম',
    'মঙ্গল',
    'বুধ',
    'বৃহস্পতি',
    'শুক্র',
    'শনি',
    'রবি',
  ];
  static const _enWeekdayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  String weekdayShort(DateTime date) => isBangla
      ? _bnWeekdayNames[date.weekday - 1]
      : _enWeekdayNames[date.weekday - 1];

  // ---- Weather Risk Center ----
  String get weatherCenterTitle =>
      isBangla ? 'আবহাওয়া ঝুঁকি কেন্দ্র' : 'Weather Risk Center';
  String get goBack => isBangla ? 'ফিরে যান' : 'Go back';
  String get forecast7Days => isBangla ? '৭ দিনের পূর্বাভাস' : '7-day forecast';
  String get dataAndEvidence => isBangla ? 'তথ্য ও উৎস' : 'Data & evidence';
  String get nowLabel => isBangla ? 'এখন' : 'Now';
  String get feelsLikeLabel => isBangla ? 'অনুভূত' : 'Feels like';
  String get rainChanceLabel => isBangla ? 'বৃষ্টির সম্ভাবনা' : 'Rain chance';
  String get riskShortLabel => isBangla ? 'ঝুঁকি' : 'Risk';
  String get hazardRainfall => isBangla ? 'বৃষ্টি' : 'Rainfall';
  String get hazardHeat => isBangla ? 'তাপ চাপ' : 'Heat stress';
  String get hazardWind => isBangla ? 'ঝড়-বাতাস' : 'Storm/Wind';
  String get todayLabel => isBangla ? 'আজ' : 'Today';
  String riskPrefixed(String level) =>
      isBangla ? 'ঝুঁকি: $level' : 'Risk: $level';
  String severityLabel(String level) =>
      isBangla ? 'তীব্রতা: $level' : 'Severity: $level';
  String get actionIrrigate => isBangla ? 'সেচ দিন' : 'Irrigate';
  String get actionReduce => isBangla ? 'সেচ কমান' : 'Reduce irrigation';
  String get actionSkip => isBangla ? 'সেচ স্থগিত' : 'Hold irrigation';
  String get decisionTitle => isBangla ? 'আজ কী করবেন?' : 'What to do today?';
  String get decisionCaption =>
      isBangla ? 'আজকের খামার সিদ্ধান্ত' : "Today's farm decision";
  String get demoGuidancePill => isBangla ? 'ডেমো নির্দেশনা' : 'Demo guidance';
  String get adviceBasisQuestion =>
      isBangla ? 'এই পরামর্শ কীসের ভিত্তিতে?' : 'What is this advice based on?';
  String get adviceBasisDemo => isBangla
      ? 'এটি নমুনা পূর্বাভাসের উপর তৈরি একটি ডেমো উদাহরণ। কোনো লাইভ আবহাওয়া উৎস বা যাচাই করা কৃষি মডেল থেকে আসেনি — চাষের সিদ্ধান্তে ব্যবহার করবেন না।'
      : 'This is a demo example built on sample forecast values. It does not come from a live weather source or a verified farming model, so do not use it for planting decisions.';
  String get adviceBasisLive => isBangla
      ? 'বর্তমান পূর্বাভাসের বৃষ্টির সম্ভাবনা থেকে তৈরি সাধারণ নির্দেশনা। স্থানীয় কৃষি কর্মকর্তার পরামর্শ নিন।'
      : 'General guidance based on the current rain-chance forecast. Check with your local agriculture officer.';
  String get dataTypeLabel => isBangla ? 'ডেটার ধরন' : 'Data type';
  String get lastUpdatedLabel => isBangla ? 'হালনাগাদের সময়' : 'Last updated';
  String get notApplicableNotFetched => isBangla
      ? 'প্রযোজ্য নয় — কোথাও থেকে আনা হয়নি'
      : 'Not applicable — not fetched from anywhere';
  String get sourceConnected => isBangla ? 'সংযুক্ত' : 'Connected';
  String get sourceNotConnected => isBangla ? 'সংযুক্ত নয়' : 'Not connected';
  String get sourceDemo => isBangla ? 'ডেমো উৎস' : 'Demo source';
  String get demoBannerTitle =>
      isBangla ? 'ডেমো ডেটা — লাইভ নয়' : 'Demo data — not live';
  String get demoBannerBody => isBangla
      ? 'এই পর্দার সব মান প্রদর্শনের জন্য তৈরি নমুনা। লাইভ আবহাওয়া উৎস এখনো সংযুক্ত হয়নি।'
      : 'Every value on this screen is a sample made for display. A live weather source is not connected yet.';
  String get cachedBannerTitle =>
      isBangla ? 'সংরক্ষিত ডেটা দেখানো হচ্ছে' : 'Showing saved data';
  String get cachedBannerBodyUnknown => isBangla
      ? 'সর্বশেষ আনা তথ্য দেখানো হচ্ছে।'
      : 'Showing the most recently fetched data.';
  String cachedBannerBodyDated(String date) => isBangla
      ? 'সর্বশেষ আনা হয়েছে $date তারিখে। নতুন তথ্যের জন্য রিফ্রেশ করুন।'
      : 'Last fetched on $date. Refresh for newer data.';
  String get offlineTitle => isBangla ? 'আপনি অফলাইনে আছেন' : "You're offline";
  String get offlineDemo => isBangla
      ? 'নিচের মানগুলো ডেমো নমুনা — আগে আনা কোনো ডেটা নয়।'
      : 'Values below are demo samples, not data fetched earlier.';
  String get offlineCached => isBangla
      ? 'শেষবার সংরক্ষিত তথ্য দেখানো হচ্ছে।'
      : 'Showing the last saved data.';
  String get offlineLive => isBangla
      ? 'সংযোগ ফিরলে তথ্য আবার হালনাগাদ করা হবে।'
      : 'Data will refresh when the connection returns.';
  String get offlineNone => isBangla
      ? 'সংযোগ ফিরলে আবার চেষ্টা করুন।'
      : 'Try again when the connection returns.';
  String get weatherLoading =>
      isBangla ? 'আবহাওয়ার তথ্য লোড হচ্ছে' : 'Loading weather data';
  String get weatherLoadFailed =>
      isBangla ? 'আবহাওয়ার তথ্য আনা যায়নি' : 'Could not load weather data';
  String get weatherRetryHint => isBangla
      ? 'কিছুক্ষণ পর আবার চেষ্টা করুন।'
      : 'Please try again in a moment.';
  String get retry => isBangla ? 'আবার চেষ্টা করুন' : 'Try again';
  String get riskLow => isBangla ? 'নিম্ন' : 'Low';
  String get riskModerate => isBangla ? 'মাঝারি' : 'Moderate';
  String get riskHigh => isBangla ? 'উচ্চ' : 'High';
  String get riskSevere => isBangla ? 'তীব্র' : 'Severe';
  String get originLive => isBangla ? 'লাইভ' : 'Live';
  String get originCached => isBangla ? 'সংরক্ষিত' : 'Cached';
  String get originDemo => isBangla ? 'ডেমো' : 'Demo';

  // ---- Voice guide menu ----
  String get voiceGuideTitle => isBangla ? 'ভয়েস গাইড' : 'Voice guide';
  String voiceGuideCurrentScreen(String title) =>
      isBangla ? 'এখন: $title' : 'Now: $title';
  String get voiceGuideNoScreen =>
      isBangla ? 'এই পাতার জন্য নির্দেশনা নেই' : 'No guide for this page';
  String get voiceGuideReadPage =>
      isBangla ? 'এই পাতার নির্দেশনা শুনুন' : 'Listen to this page';
  String get voiceGuideTour =>
      isBangla ? 'পুরো অ্যাপ ঘুরে শুনুন' : 'Listen while touring the app';
  String get voiceGuideStop =>
      isBangla ? 'ভয়েস গাইড থামান' : 'Stop voice guide';
  String get voiceNotInstalled => isBangla
      ? 'এই ডিভাইসে বাংলা ভয়েস পাওয়া যায়নি। ডিভাইসের টেক্সট-টু-স্পিচ সেটিংসে বাংলা ভয়েস যোগ করুন।'
      : 'No English voice is installed on this device. Add an English text-to-speech voice in the device settings.';

  // ---- My Fields ----
  String get myFieldsSyncQueue =>
      isBangla ? 'অফলাইন সিঙ্ক কিউ' : 'Offline sync queue';
  String get syncNow => isBangla ? 'এখন সিঙ্ক করুন' : 'Sync now';
  String conflictBlockedSummary(int conflicts, int blocked) => isBangla
      ? '${digits(conflicts)}টি কনফ্লিক্ট / ${digits(blocked)}টি ব্লকেড সিঙ্ক সমস্যা রয়েছে'
      : '$conflicts conflicts / $blocked blocked sync issues';
  String pendingSyncSummary(int pending) => isBangla
      ? '${digits(pending)}টি পরিবর্তন সিঙ্কের অপেক্ষায় আছে'
      : '$pending ${pending == 1 ? 'change' : 'changes'} waiting to sync';
  String get loadingFields => isBangla ? 'জমি লোড হচ্ছে...' : 'Loading fields...';
  String fieldsSummary(int count, String acres) => isBangla
      ? '${digits(count)}টি জমি • ${digits(acres)} একর'
      : '$count ${count == 1 ? 'field' : 'fields'} • $acres acres';
  String acresText(String value) =>
      isBangla ? '${digits(value)} একর' : '$value acres';
  String get tryAgainAction =>
      isBangla ? 'পুনরায় চেষ্টা করুন' : 'Try again';
  String get noFieldsYet =>
      isBangla ? 'এখনও কোনো জমি যোগ করা হয়নি' : 'No fields added yet';
  String get firstFieldHint => isBangla
      ? 'আপনার প্রথম জমি যোগ করে স্বাস্থ্য পর্যবেক্ষণ শুরু করুন।'
      : 'Add your first field to start monitoring its health.';
  String get addFieldAction => isBangla ? 'জমি যোগ করুন' : 'Add field';
  String get boundaryLabel => isBangla ? 'জমির সীমানা' : 'Field boundary';
  String get totalFieldsLabel => isBangla ? 'মোট জমি' : 'Total fields';
  String get totalAcresLabel => isBangla ? 'মোট একর' : 'Total acres';
  String get activeLabel => isBangla ? 'সক্রিয়' : 'Active';
  String get yourFieldsTitle => isBangla ? 'আপনার জমি' : 'Your fields';
  String get satelliteNotRunYet => isBangla
      ? 'স্যাটেলাইট বিশ্লেষণ এখনো হয়নি'
      : 'No satellite analysis yet';
  String get satelliteWaitingHint => isBangla
      ? 'বিশ্লেষণের অপেক্ষায় • জমির স্বাস্থ্য ও ঝুঁকির তথ্য যুক্ত হলে এখানে দেখা যাবে।'
      : 'Waiting for analysis • Field health and risk details will appear here.';
  String get newFieldFallback => isBangla ? 'নতুন জমি' : 'New field';
  String get syncPendingStatus =>
      isBangla ? 'সিঙ্কের অপেক্ষায়' : 'Waiting to sync';
  String get conflictStatus => isBangla ? 'কনফ্লিক্ট' : 'Conflict';
  String get blockedStatus => isBangla ? 'ব্লকড' : 'Blocked';
  String get savedLocallyNeedsSync => isBangla
      ? 'স্থানীয়ভাবে সংরক্ষিত (সিঙ্ক প্রয়োজন)'
      : 'Saved locally (needs sync)';
  String get statusActive => isBangla ? 'সক্রিয়' : 'Active';
  String get statusInactive => isBangla ? 'নিষ্ক্রিয়' : 'Inactive';
  String get statusArchived => isBangla ? 'সংরক্ষণাগারে' : 'Archived';

  // ---- Field details ----
  String get fieldDetailsTitle => isBangla ? 'জমির বিস্তারিত' : 'Field details';
  String get fieldNotFound => isBangla
      ? 'জমিটি খুঁজে পাওয়া যায়নি।'
      : 'This field could not be found.';
  String get areaServerLabel => isBangla
      ? 'পরিমাণ (সার্ভার হিসাবকৃত)'
      : 'Area (calculated by server)';
  String get fieldStatusLabel => isBangla ? 'অবস্থা' : 'Status';
  String get cropCyclesTitle => isBangla ? 'ফসল চক্র' : 'Crop cycles';
  String get noCropCyclesYet => isBangla
      ? 'এই জমিতে এখনো কোনো ফসল চক্র যোগ করা হয়নি।'
      : 'No crop cycles have been added to this field yet.';
  String cycleStage(String stage) =>
      isBangla ? 'পর্যায়: $stage' : 'Stage: $stage';
  String plantedOn(String date) =>
      isBangla ? 'রোপণ: $date' : 'Planted: $date';
  String expectedHarvest(String date) =>
      isBangla ? 'প্রত্যাশিত ফসল কাটা: $date' : 'Expected harvest: $date';
  String get cycleStatusPlanned => isBangla ? 'পরিকল্পিত' : 'Planned';
  String get cycleStatusActive => isBangla ? 'সক্রিয়' : 'Active';
  String get cycleStatusHarvested => isBangla ? 'কাটা হয়েছে' : 'Harvested';
  String get cycleStatusFailed => isBangla ? 'ব্যর্থ' : 'Failed';
  String get cycleStatusCancelled => isBangla ? 'বাতিল' : 'Cancelled';

  // ---- Add field sheet ----
  String get addFieldTitle => isBangla ? 'নতুন জমি যোগ করুন' : 'Add new field';
  String get addFieldStep1 => isBangla
      ? 'ধাপ ১ / ২ • জমির তথ্য ও সীমানা'
      : 'Step 1 of 2 • Field details and boundary';
  String get fieldNameLabel => isBangla ? 'জমির নাম' : 'Field name';
  String get fieldNameHint => isBangla ? 'যেমন: উত্তর জমি' : 'e.g. North field';
  String get fieldNameRequired =>
      isBangla ? 'জমির নাম আবশ্যক' : 'Field name is required';
  String get countryCodeLabel =>
      isBangla ? 'দেশের কোড (ISO 3166-1)' : 'Country code (ISO 3166-1)';
  String get countryCodeHint => isBangla ? 'যেমন: BD' : 'e.g. BD';
  String get countryCodeInvalid =>
      isBangla ? '২ অক্ষরের দেশের কোড দিন' : 'Enter a 2-letter country code';
  String get divisionLabel =>
      isBangla ? 'বিভাগ (ঐচ্ছিক)' : 'Division (optional)';
  String get divisionHint => isBangla ? 'যেমন: ঢাকা' : 'e.g. Dhaka';
  String get districtOptionalLabel =>
      isBangla ? 'জেলা (ঐচ্ছিক)' : 'District (optional)';
  String get districtOptionalHint =>
      isBangla ? 'যেমন: কিশোরগঞ্জ' : 'e.g. Kishoreganj';
  String get upazilaLabel =>
      isBangla ? 'উপজেলা (ঐচ্ছিক)' : 'Upazila (optional)';
  String get upazilaHint => isBangla ? 'যেমন: ভৈরব' : 'e.g. Bhairab';
  String get nextAddCrop =>
      isBangla ? 'পরবর্তী: ফসল যোগ করুন' : 'Next: add a crop';
  String get boundaryRequired => isBangla
      ? 'জমির সীমানা আঁকা আবশ্যক'
      : 'Draw the field boundary first';
  String boundaryDrawnCount(int points) => isBangla
      ? 'সীমানা আঁকা হয়েছে ($points টি বিন্দু)'
      : 'Boundary drawn ($points points)';
  String get tapMapToDrawBoundary => isBangla
      ? 'মানচিত্রে ট্যাপ করে সীমানা আঁকুন'
      : 'Tap the map to draw the boundary';
  String savedOfflineQueue(String name) => isBangla
      ? '"$name" অফলাইন সিঙ্ক কিউতে রাখা হয়েছে (সিঙ্কের অপেক্ষায়)'
      : '"$name" is in the offline sync queue, waiting to sync';
  String fieldSaved(String name) =>
      isBangla ? '"$name" জমি সংরক্ষিত হয়েছে' : '"$name" was saved';
  String get addCropTitle => isBangla ? 'ফসল চক্র যোগ করুন' : 'Add crop cycle';
  String get addCropStep2 => isBangla
      ? 'ধাপ ২ / ২ • ঐচ্ছিক, তবে সুপারিশকৃত'
      : 'Step 2 of 2 • Optional, but recommended';
  String get cropCodeLabel => isBangla ? 'ফসলের কোড' : 'Crop code';
  String get cropCodeHint => isBangla ? 'যেমন: RICE_BORO' : 'e.g. RICE_BORO';
  String get cropCodeRequired =>
      isBangla ? 'ফসলের কোড আবশ্যক' : 'Crop code is required';
  String get varietyLabel => isBangla ? 'জাত (ঐচ্ছিক)' : 'Variety (optional)';
  String get varietyHint => isBangla ? 'যেমন: BRRI dhan28' : 'e.g. BRRI dhan28';
  String get addCropCycleAction =>
      isBangla ? 'ফসল চক্র যোগ করুন' : 'Add crop cycle';
  String get addLaterAction => isBangla ? 'পরে যোগ করব' : 'I will add it later';
  String get savedInSyncQueue =>
      isBangla ? 'সিঙ্ক কিউতে সংরক্ষিত' : 'Saved in sync queue';
  String get doneLabel => isBangla ? 'সম্পন্ন হয়েছে' : 'Done';
  String successOfflineText(String name) => isBangla
      ? '"$name" এবং ফসল চক্র সিঙ্ক কিউতে জমা রাখা হয়েছে। ইন্টারনেট সংযোগ পেলেই সার্ভারে জমা হবে।'
      : '"$name" and its crop cycle are queued. They will be sent to the server once you are online.';
  String successSavedText(String name) => isBangla
      ? '"$name" এবং এর ফসল চক্র সংরক্ষিত হয়েছে।'
      : '"$name" and its crop cycle are saved.';
  String get closeAction => isBangla ? 'বন্ধ করুন' : 'Close';

  // ---- Field boundary picker ----
  String get boundaryPickerTitle =>
      isBangla ? 'জমির সীমানা আঁকুন' : 'Draw field boundary';
  String boundaryPointsMarked(int points) => isBangla
      ? 'সীমানার $points টি বিন্দু চিহ্নিত হয়েছে। নিশ্চিত করুন বা আরও বিন্দু যোগ করুন।'
      : '$points boundary points marked. Confirm, or add more points.';
  String boundaryTapHint(int minimum) => isBangla
      ? 'জমির সীমানা বরাবর ট্যাপ করে কমপক্ষে $minimum টি বিন্দু চিহ্নিত করুন।'
      : 'Tap along the field edge to mark at least $minimum points.';
  String get confirmBoundary =>
      isBangla ? 'সীমানা নিশ্চিত করুন' : 'Confirm boundary';

  // ---- Satellite map ----
  String get satMyFieldTwin => isBangla
      ? 'আমার জমি (ডিজিটাল টুইন)'
      : 'My field (digital twin)';
  String satFieldLine(String name, String crop, String area) =>
      '$name • $crop ($area)';
  String satDemoImage(String tag) => isBangla ? '$tag চিত্র' : '$tag image';
  String get satNdviHealth => isBangla ? 'NDVI স্বাস্থ্য' : 'NDVI health';
  String get satSoilMoisture => isBangla ? 'মাটির আর্দ্রতা' : 'Soil moisture';
  String get satRiskLevel => isBangla ? 'ঝুঁকি স্তর' : 'Risk level';
  String get satLowHealthZone =>
      isBangla ? 'এই অংশে স্বাস্থ্য কম' : 'Health is low in this area';
  String get satLegendWeak => isBangla ? 'দুর্বল' : 'Weak';
  String get satLegendHealthy => isBangla ? 'সুস্থ' : 'Healthy';
  String get satHealthOverall => isBangla
      ? 'সারগ্রাহ্য জমির স্বাস্থ্য: ভালো'
      : 'Overall field health: good';
  String get satDemoNoLivePass => isBangla
      ? 'ডেমো চিত্র · লাইভ স্যাটেলাইট পাস সংযুক্ত নয়'
      : 'Demo image · live satellite pass not connected';
  String get satAlertsTitle =>
      isBangla ? 'শনাক্তকৃত সমস্যাসমূহ' : 'Detected issues (satellite alerts)';
  String get satLeafBlastTitle => isBangla
      ? 'সম্ভাব্য পাতা রোগ (ব্লাস্ট সন্দেহ)'
      : 'Possible leaf disease (suspected blast)';
  String satLeafBlastDesc(String zone) => isBangla
      ? '$zone পাতার প্রতিচ্ছবিতে অসমতা পাওয়া গেছে।'
      : 'Uneven leaf pattern detected $zone.';
  String get satWaterloggingTitle =>
      isBangla ? 'অতিরিক্ত পানি জমেছে' : 'Excess water is pooling';
  String satWaterloggingDesc(String zone) => isBangla
      ? 'জমির $zone ড্রেনেজের তুলনায় পানি জমে থাকার সূচক বেশি।'
      : 'The water-retention signal is higher than drainage $zone.';
  String get satAlertInfo => isBangla ? 'তথ্য' : 'Info';
  String get satAlertWarning => isBangla ? 'সতর্কতা' : 'Warning';
  String get satAlertSatisfactory => isBangla ? 'সন্তোষজনক' : 'Satisfactory';
  String get satGrowthNormalTitle => isBangla
      ? 'উদ্ভিদের বৃদ্ধির ঘনত্ব স্বাভাবিক'
      : 'Plant growth density is normal';
  String get satGrowthNormalDesc => isBangla
      ? 'বাকি অংশ জুড়ে ফসলের উচ্চতা ও ঘনত্ব আশানুরূপ।'
      : 'Crop height and density are as expected across the rest of the field.';
  String get satSpotScan =>
      isBangla ? 'স্পট স্ক্যান প্রস্তাবনা' : 'Spot scan suggestion';
  String get satNorthDecline => isBangla
      ? 'উত্তর অংশে স্বাস্থ্যের অবনতি হয়েছে'
      : 'Crop health has declined in the north part';
  String get satScanNow => isBangla ? 'স্ক্যান করুন →' : 'Scan now →';

  // ---- Field insights ----
  String get insFieldInsightsTitle =>
      isBangla ? 'জমির ইনসাইট' : 'Field Insights';
  String get insDemoBadge => isBangla ? 'ডেমো' : 'DEMO';
  String get insHealthyTitle =>
      isBangla ? 'জমির অবস্থা ভালো' : 'Field condition is good';
  String insMostlyHealthy(String zone) => isBangla
      ? 'বেশিরভাগ অংশ সুস্থ। $zone একটু নজর দেওয়া দরকার।'
      : 'Most of the field is healthy. The area $zone needs a closer look.';
  String get insPestRisk => isBangla ? 'পোকার ঝুঁকি' : 'Pest risk';
  String get insCropHealthTrend =>
      isBangla ? 'ফসলের স্বাস্থ্যের প্রবণতা' : 'Crop health trend';
  String insChartDay(int day) =>
      isBangla ? '${digits(day)} সেপ্টে' : 'Sep $day';
  String get insAiInsight => isBangla ? 'এআই ইনসাইট' : 'AI insight';
  String get insMostImportant =>
      isBangla ? 'সবচেয়ে গুরুত্বপূর্ণ' : 'Most important';
  String insWaterSignal(String zone) => isBangla
      ? '$zone পানি বেশি থাকার সংকেত পাওয়া গেছে।'
      : 'Signs of excess water $zone.';
  String get insAdvice => isBangla
      ? 'আজ অতিরিক্ত সেচ দেবেন না। একটি মাঠের ছবি দিলে এআই আরও নিশ্চিত হতে পারবে।'
      : 'Do not irrigate extra today. If you send a field photo, the AI can be more certain.';
  String get insWhyAlert => isBangla ? 'এই সতর্কতা কেন?' : 'Why this alert?';
  String get insRecentRainfall =>
      isBangla ? 'সাম্প্রতিক বৃষ্টি' : 'Recent rainfall';
  String get insWaterSignalTitle => isBangla ? 'পানির সংকেত' : 'Water signal';
  String get insDetected => isBangla ? 'শনাক্ত হয়েছে' : 'Detected';
  String get insLowElevation =>
      isBangla ? 'নিচু জায়গা' : 'Low elevation area';
  String get insYes => isBangla ? 'হ্যাঁ' : 'Yes';
  String get insOpenSatellite =>
      isBangla ? 'স্যাটেলাইট ম্যাপ দেখুন' : 'View satellite map';

  // ---- Plant scan ----
  String get scanCameraPermissionNeeded => isBangla
      ? 'প্ল্যান্ট স্ক্যান করতে ক্যামেরার অনুমতি দরকার।'
      : 'Camera permission is required to scan a plant.';
  String get scanCameraStartFailed => isBangla
      ? 'এই ডিভাইসে ক্যামেরা চালু করা যাচ্ছে না।'
      : 'Unable to start the camera on this device.';
  String get scanFlashUnsupported => isBangla
      ? 'এই ক্যামেরায় ফ্লাশ সমর্থিত নয়।'
      : 'Flash is not supported by this camera.';
  String scanZoomUnsupported(Object zoom) => isBangla
      ? '${digits(zoom)}× জুম এই ক্যামেরায় সমর্থিত নয়।'
      : '$zoom× zoom is not supported by this camera.';
  String get scanZoomUnavailable =>
      isBangla ? 'এখন জুম করা যাচ্ছে না।' : 'Zoom is not available right now.';
  String get scanCameraNotReady =>
      isBangla ? 'ক্যামেরা এখনও প্রস্তুত নয়।' : 'Camera is not ready yet.';
  String get scanCaptureFailed => isBangla
      ? 'ছবি তোলা যায়নি। আবার চেষ্টা করুন।'
      : 'Photo capture failed. Please try again.';
  String get scanCameraUnavailable =>
      isBangla ? 'ক্যামেরা পাওয়া যাচ্ছে না।' : 'Camera is unavailable.';
  String get scanTitle => isBangla ? 'প্ল্যান্ট স্ক্যান' : 'Scan plant';
  String get scanCenterLeaf => isBangla
      ? 'আক্রান্ত পাতা ফ্রেমের মাঝে রাখুন'
      : 'Center the affected leaf in the frame';
  String get flashAuto => isBangla ? 'স্বয়ংক্রিয়' : 'Auto';
  String get flashOff => isBangla ? 'বন্ধ' : 'Off';
  String get scanKeepFocus => isBangla
      ? 'আক্রান্ত অংশ ফোকাসে রাখুন'
      : 'Keep the affected area in focus';
  String get photoGuideTitle => isBangla ? 'ফটোগ্রাফি গাইড' : 'Photo guide';
  String get howToTakePhoto => isBangla ? 'কীভাবে ছবি তুলবেন' : 'How to take a photo';
  String get exampleGood => isBangla ? 'ভালো উদাহরণ' : 'Good example';
  String get exampleGoodDesc =>
      isBangla ? 'স্পষ্ট ও মাঝখানে পাতা' : 'Sharp and centred leaf';
  String get exampleTooFar => isBangla ? 'অনেক দূরে' : 'Too far';
  String get exampleTooFarDesc => isBangla ? 'আরও কাছে যান' : 'Move closer';
  String get exampleBlurry => isBangla ? 'ঝাপসা' : 'Blurry';
  String get exampleBlurryDesc =>
      isBangla ? 'ক্যামেরা স্থির রাখুন' : 'Hold the camera steady';
  String get exampleObstructed => isBangla ? 'ঢাকা পড়েছে' : 'Obstructed';
  String get exampleObstructedDesc =>
      isBangla ? 'আঙুল বা ছায়া এড়িয়ে চলুন' : 'Avoid fingers and shadow';
  String get galleryLabel => isBangla ? 'গ্যালারি' : 'Gallery';
  String get galleryUnavailable => isBangla
      ? 'গ্যালারি থেকে ছবি বাছাই এখনো পাওয়া যাচ্ছে না।'
      : 'Gallery selection is not available yet.';
  String get tipsLabel => isBangla ? 'টিপস' : 'Tips';
  String get photographyGuidelines =>
      isBangla ? 'ফটোগ্রাফি গাইডলাইন' : 'Photography guidelines';
  String get guideTip1 => isBangla
      ? '১. আক্রান্ত পাতার ওপর ক্যামেরা স্থির রাখুন।'
      : '1. Hold the camera steady over the affected leaf.';
  String get guideTip2 => isBangla
      ? '২. পর্যাপ্ত প্রাকৃতিক আলোতে ছবি তুলুন।'
      : '2. Take the photo in good natural light.';
  String get guideTip3 => isBangla
      ? '৩. ক্যামেরায় শুধু একটি পাতা ফোকাস করুন।'
      : '3. Focus the camera on one leaf only.';
  String get guideTip4 => isBangla
      ? '৪. ছায়া বা আঙুল দিয়ে পাতা ঢেকে রাখবেন না।'
      : '4. Do not cover the leaf with a shadow or your fingers.';
  String get gotIt => isBangla ? 'বুঝেছি' : 'Got it';

  // ---- Diagnosis result (demo output; see DemoStory) ----
  String get diagResultTitle => isBangla
      ? 'রোগ শনাক্তকরণ ফলাফল'
      : 'Disease detection result';
  String get diagResultSubtitle => isBangla
      ? 'ডেমো ফলাফল'
      : 'Demo result';
  String get diagSaveUnavailable => isBangla
      ? 'এখনো ফলাফল সংরক্ষণের সুবিধা চালু হয়নি।'
      : 'Saving results is not available yet.';
  String get diagShareUnavailable => isBangla
      ? 'শেয়ার করার সুবিধা এখনো চালু হয়নি।'
      : 'Sharing is not available yet.';
  String get diagCapturedPhoto => isBangla ? 'তোলা ছবি' : 'Captured photo';
  String get diagUrgent =>
      isBangla ? 'জরুরি মনোযোগ প্রয়োজন' : 'Needs urgent attention';
  String diagConfidenceBadge(int percent) => isBangla
      ? 'AI নির্ভরতা ${digits(percent)}%'
      : 'AI confidence $percent%';
  String get diagHighReliability =>
      isBangla ? 'উচ্চ নির্ভরযোগ্যতা' : 'High reliability';
  String get diagRiskLevelLabel => isBangla ? 'ঝুঁকির মাত্রা:' : 'Risk level:';
  String get diagRiskRange => isBangla ? 'মাঝারি - উচ্চ' : 'Moderate to high';
  String get diagLevelLow => isBangla ? 'কম' : 'Low';
  String get diagLevelModerate => isBangla ? 'মাঝারি' : 'Moderate';
  String get diagLevelHigh => isBangla ? 'উচ্চ' : 'High';
  String get diagAffectedArea => isBangla ? 'আক্রান্ত এলাকা' : 'Affected area';
  String get diagLeafArea => isBangla ? 'পাতার ক্ষেত্রফল' : 'Leaf area';
  String get diagYieldRisk => isBangla ? 'ফলন ঝুঁকি' : 'Yield risk';
  String get diagWithoutTreatment =>
      isBangla ? 'প্রতিকার ছাড়া' : 'Without treatment';
  String get diagSpreadSpeed => isBangla ? 'বিস্তার গতি' : 'Spread speed';
  String get diagFast => isBangla ? 'দ্রুত' : 'Fast';
  String get diagHumidWeather =>
      isBangla ? 'আর্দ্র আবহাওয়া' : 'Humid weather';
  String get diagTodayActions => isBangla
      ? 'আজ কী করবেন? (জরুরি ৩টি পদক্ষেপ)'
      : 'What to do today? (3 urgent steps)';
  String get diagStep1Title => isBangla
      ? 'অতিরিক্ত নাইট্রোজেন সার বন্ধ করুন'
      : 'Stop extra nitrogen fertilizer';
  String get diagStep1Desc => isBangla
      ? 'ইউরিয়া প্রয়োগ ব্লাস্ট রোগের বিস্তারকে ত্বরান্বিত করে। অবিলম্বে প্রয়োগ স্থগিত রাখুন।'
      : 'Applying urea speeds up the spread of blast disease. Hold any application now.';
  String get diagStep2Title => isBangla
      ? 'জমির পানি ২-৩ দিনের জন্য কমিয়ে দিন'
      : 'Lower the field water for 2–3 days';
  String get diagStep2Desc => isBangla
      ? 'ক্ষেতের পানি শুকিয়ে ড্রেনেজ দিন যাতে পাতার স্যাঁতসেঁতে ভাব ও আর্দ্রতা কমে।'
      : 'Let the field drain so that wetness and humidity around the leaves decrease.';
  String get diagStep3Title => isBangla
      ? 'অনুমোদিত ট্রাইসাইক্লাজল স্প্রে করুন'
      : 'Spray approved tricyclazole';
  String get diagStep3Desc => isBangla
      ? 'প্রতি লিটার পানিতে ০.৭৫ গ্রাম ট্রাইসাইক্লাজল ৭৫ ডব্লিউপি বিকেলে ভালো করে স্প্রে করুন।'
      : 'Spray 0.75 g of tricyclazole 75 WP per litre of water thoroughly in the afternoon.';
  String get diagSimilarCases =>
      isBangla ? 'অনুরূপ রোগ তুলনা' : 'Similar disease comparison';
  String get diagModelResult => isBangla ? 'মডেল ফলাফল' : 'Model result';
  String get diagModelBrownSpot => isBangla ? 'বাদামী দাগ' : 'Brown Spot';
  String get diagModelLeafSmut => isBangla ? 'পাতা পোড়া' : 'Leaf Smut';
  String get diagModelHealthyLeaf => isBangla ? 'সুস্থ পাতা' : 'Healthy Leaf';
  String get diagWhyAiTitle =>
      isBangla ? 'কেন AI এমন মনে করছে?' : 'Why does the AI think so?';
  String get diagWhyAiSubtitle =>
      isBangla ? 'ডায়াগনসিস ব্যাখ্যা ও কারণ' : 'Diagnosis explanation and reasons';
  String get diagWhyAiContent => isBangla
      ? 'পাতার কেন্দ্রে চোখা বা টাকু আকৃতির দাগ, চারপাশে গাঢ় বাদামী সীমানা এবং কেন্দ্রে ধূসর রঙ স্পষ্টভাবে ব্লাস্ট ছত্রাকের (Magnaporthe oryzae) সাধারণ উপসর্গ নির্দেশ করে।'
      : 'Sharp, needle-shaped spots at the centre of the leaf, a dark brown border around them and grey colour in the centre clearly point to the usual symptoms of blast fungus (Magnaporthe oryzae).';
  String get diagWeatherSpreadTitle => isBangla
      ? 'এই রোগের বিস্তার ঝুঁকি ও আবহাওয়া'
      : 'Spread risk of this disease and the weather';
  String get diagWeatherSpreadSubtitle =>
      isBangla ? 'বর্তমান আবহাওয়া প্রভাব' : 'Current weather effect';
  String get diagWeatherSpreadContent => isBangla
      ? 'রাতের শিশির এবং দিনের ২৬°-২৮° সেলসিয়াস তাপমাত্রা স্পোর অঙ্কুরোদগমের জন্য অত্যন্ত অনুকূল। আগামী ৩ দিন সতর্ক দৃষ্টি রাখুন।'
      : 'Night dew and day temperatures of 26–28 °C are very favourable for spore germination. Keep a close watch for the next 3 days.';
  String get diagViewFullPlan => isBangla
      ? 'সম্পূর্ণ ব্যবস্থাপনা পরিকল্পনা দেখুন'
      : 'View the full management plan';

  // ---- Treatment plan (demo plan; see DemoStory) ----
  String get treatPlanTitle =>
      isBangla ? '৭ দিনের ব্যবস্থাপনা পরিকল্পনা' : '7-day management plan';
  String treatSubtitle(String disease, String field, String area) =>
      '$disease • $field ($area)';
  String get treatDemoNotice => isBangla
      ? 'ডেমো নমুনা — এটি যাচাইকৃত কৃষি পরামর্শ নয়। ওষুধ বা মাত্রা প্রয়োগের আগে স্থানীয় কৃষি কর্মকর্তার পরামর্শ ও পণ্যের অনুমোদিত লেবেল যাচাই করুন।'
      : 'Demo sample. This is not verified farming advice. Before applying any medicine or dose, check with your local agriculture officer and the product\'s approved label.';
  String get treatNextEvaluation =>
      isBangla ? 'পরবর্তী মূল্যায়ন' : 'Next evaluation';
  String treatHoursLeft(int hours) =>
      isBangla ? '${digits(hours)} ঘণ্টা বাকি' : '$hours hours left';
  String get treatPhotoNote => isBangla
      ? 'প্রথম ধাপের স্প্রে করার পর অগ্রগতি দেখতে নতুন ছবি তুলবেন।'
      : 'After the first spray, take a new photo to check progress.';
  String get treatTimelineTitle =>
      isBangla ? 'কর্মপরিকল্পনা টাইমলাইন' : 'Action timeline';
  String get treatStep1Day => isBangla ? 'আজ • ১ম দিন' : 'Today • Day 1';
  String get treatStep1Badge => isBangla ? 'চলমান' : 'In progress';
  String get treatStep1Title => isBangla
      ? 'জরুরি নিষ্কাশন ও নাইট্রোজেন স্থগিত'
      : 'Urgent drainage and nitrogen hold';
  String get treatStep1Desc => isBangla
      ? 'ইউরিয়া প্রয়োগ অবিলম্বে বন্ধ করুন এবং জমির অতিরিক্ত পানি নিষ্কাশন করে ২ সে.মি. ড্রেন করুন।'
      : 'Stop applying urea now, and drain excess water from the field to 2 cm.';
  String get treatStep1Task1 =>
      isBangla ? 'ইউরিয়া সার ছিটানো বন্ধ রাখা' : 'Keep urea spreading stopped';
  String get treatStep1Task2 =>
      isBangla ? 'জমির পানি নিষ্কাশন করা' : 'Drain the field water';
  String get treatStep1Task3 => isBangla
      ? 'আক্রান্ত গাছ থেকে শুকনো পাতা ছাঁটাই'
      : 'Trim dry leaves from affected plants';
  String get treatStep2Day => isBangla ? 'দিন ২–৩' : 'Days 2–3';
  String get treatStep2Badge => isBangla ? 'আসন্ন' : 'Upcoming';
  String get treatStep2Title =>
      isBangla ? 'ছত্রাকনাশক স্প্রে' : 'Fungicide spray';
  String get treatStep2Desc => isBangla
      ? 'ট্রাইসাইক্লাজল ৭৫ ডব্লিউপি প্রতি লিটার পানিতে ০.৭৫ গ্রাম গুলে বিকেলে সম্পূর্ণ পাতায় স্প্রে করুন।'
      : 'Mix 0.75 g of tricyclazole 75 WP per litre of water and spray the whole leaf surface in the afternoon.';
  String get treatStep2Task1 =>
      isBangla ? 'অনুমোদিত ছত্রাকনাশক সংগ্রহ' : 'Get an approved fungicide';
  String get treatStep2Task2 => isBangla
      ? 'বিকেলে রোদের তীব্রতা কমার পর স্প্রে করা'
      : 'Spray in the afternoon, after the sun is less strong';
  String get treatStep2Task3 => isBangla
      ? 'স্প্রে করার সময় নিরাপত্তা মাস্ক ও গ্লাভস পরা'
      : 'Wear a safety mask and gloves while spraying';
  String get treatStep3Day => isBangla ? 'দিন ৫–৭' : 'Days 5–7';
  String get treatStep3Badge => isBangla ? 'পরিকল্পিত' : 'Planned';
  String get treatStep3Title => isBangla
      ? 'ফলাফল পর্যবেক্ষণ ও পুনর্মূল্যায়ন'
      : 'Check results and reassess';
  String get treatStep3Desc => isBangla
      ? 'নতুন কুশি ও কচি পাতায় কোনো দাগ আছে কিনা পরীক্ষা করুন এবং অ্যাপ দিয়ে পুনরায় গ্রাউন্ড স্ক্যান করুন।'
      : 'Check new tillers and young leaves for spots, and scan the ground again with the app.';
  String get treatStep3Task1 =>
      isBangla ? 'নতুন কুশিতে দাগ পরীক্ষা' : 'Check new tillers for spots';
  String get treatStep3Task2 =>
      isBangla ? 'অ্যাপ দিয়ে ২য় বার স্পট স্ক্যান' : 'Second spot scan with the app';
  String get treatStep3Task3 => isBangla
      ? 'অগ্রগতি ভালো হলে সাধারণ পরিচর্যা পুনরায় শুরু'
      : 'If progress is good, resume normal care';
  String get treatWhyTitle => isBangla ? 'কেন এই পরিকল্পনা?' : 'Why this plan?';
  String get treatWhyBody => isBangla
      ? 'বাংলাদেশ ধান গবেষণা ইনস্টিটিউট (BRRI) ও আন্তর্জাতিক ধান গবেষণা ইনস্টিটিউট (IRRI)-এর প্রোটোকল মেনে বোরো ধানের জন্য নিখুঁতভাবে প্রণীত।'
      : 'Prepared for boro rice following the protocols of the Bangladesh Rice Research Institute (BRRI) and the International Rice Research Institute (IRRI).';
  String get treatWarningTitle =>
      isBangla ? 'মনে রাখুন (সতর্কতা)' : 'Remember (warning)';
  String get treatWarningBody => isBangla
      ? 'বৃষ্টির সম্ভাবনা থাকলে অথবা বাতাসের গতিবেগ বেশি থাকলে কোনো রাসায়নিক স্প্রে করবেন না। ওষুধ মিশ্রণের সময় শিশুদের দূরে রাখুন।'
      : 'Do not spray any chemical when rain is likely or the wind is strong. Keep children away while mixing medicine.';
  String get treatListen => isBangla ? 'শুনুন' : 'Listen';
  String get treatDemoDialogTitle => isBangla ? 'ডেমো পরিকল্পনা' : 'Demo plan';
  String get treatDemoDialogBody => isBangla
      ? 'এটি একটি ডেমো পরিকল্পনা। ট্র্যাকিং ও দৈনিক নোটিফিকেশন এখনো চালু হয়নি।'
      : 'This is a demo plan. Tracking and daily reminders are not connected yet.';
  String get treatOk => isBangla ? 'ঠিক আছে' : 'OK';
  String get treatStartPlan =>
      isBangla ? 'পরিকল্পনা শুরু করুন →' : 'Start plan →';
  String get treatMarkedDemo =>
      isBangla ? 'ডেমো হিসেবে চিহ্নিত ✓' : 'Marked as demo ✓';

  // ---- Home dashboard ----
  String get brandTagline =>
      isBangla ? 'সবুজ আগামীর জন্য এআই' : 'AI for a Greener Tomorrow';
  String get heroTitleLead => isBangla ? 'আপনার খামার,' : 'Your Farm,';
  String get heroAccentLead => isBangla ? 'আমাদের ' : 'Our ';
  String get heroAccentWord => isBangla ? 'বুদ্ধিমত্তা' : 'Intelligence';
  String get heroSubtitle => isBangla
      ? 'রিয়েল-টাইম তথ্য। সুস্থ ফসল।\nউজ্জ্বল বাংলাদেশ।'
      : 'Real-time insights. Healthier crops.\nBrighter Bangladesh.';
  String get searchFieldHint => isBangla
      ? 'জমি, ফসল বা সমস্যা খুঁজুন...'
      : 'Search field, crop or issue...';
  String get healthyFieldsTagline => isBangla ? 'সুস্থ মাঠ' : 'Healthy Fields';
  String get brighterFuturesTagline =>
      isBangla ? 'উজ্জ্বল ভবিষ্যৎ' : 'Brighter Futures';
  String get humidityLabel => isBangla ? 'আর্দ্রতা' : 'Humidity';
  String get cropConditionLabel => isBangla ? 'ফসলের অবস্থা' : 'Crop Condition';
  String get cropConditionGood => isBangla ? 'ভালো' : 'Good';
  String get seeAll => isBangla ? 'সব দেখুন' : 'See All';
  String get healthyStatus => isBangla ? 'সুস্থ' : 'Healthy';
  String get demoFieldLabel => isBangla ? 'ডেমো মাঠ' : 'Demo field';
  String get quickActions => isBangla ? 'দ্রুত কাজ' : 'Quick Actions';
  String get scanPlantTitle => isBangla ? 'গাছ স্ক্যান' : 'Scan Plant';
  String get scanPlantSubtitle =>
      isBangla ? 'রোগ শনাক্ত করুন' : 'Detect disease';
  String get weatherTitle => isBangla ? 'আবহাওয়া' : 'Weather';
  String get weatherSubtitle => isBangla ? 'মাঠের পূর্বাভাস' : 'Field forecast';
  String get marketPriceTitle => isBangla ? 'বাজার দর' : 'Market Price';
  String get marketPriceSubtitle => isBangla ? 'ডেমো দর' : 'Demo rates';
  String get expertHelpTitle => isBangla ? 'কৃষি সহকারী' : 'Expert Help';
  String get expertHelpSubtitle => isBangla ? 'পরামর্শ নিন' : 'Get advice';
  String get promoTitle =>
      isBangla ? 'সুস্থ ফসল,\nবেশি ফলন' : 'Healthier Crops\nHigher Yields';
  String get promoSubtitle => isBangla
      ? 'প্রতিটি কৃষকের জন্য এআই-চালিত তথ্য'
      : 'AI-powered insights for every farmer';

  // ---- Onboarding: language step ----
  String get chooseAppLanguage =>
      isBangla ? 'কোন ভাষায় চালাবেন?' : 'Which language should we use?';
  String get languageChangeLater => isBangla
      ? 'পরে সেটিংস থেকে যেকোনো সময় বদলাতে পারবেন।'
      : 'You can change this later in Settings.';
  String get banglaMainLanguage =>
      isBangla ? 'অ্যাপের মূল ভাষা' : 'Main app language';
  String get englishInterface =>
      isBangla ? 'ইংরেজিতে অ্যাপ' : 'English interface';

  // ---- Onboarding: location step ----
  String get locationEyebrow => isBangla ? 'খামারের অবস্থান' : 'FARM LOCATION';
  String get whereIsFarm =>
      isBangla ? 'আপনার খামার কোথায়?' : 'Where is your farm?';
  String get locationSubtitle => isBangla
      ? 'আবহাওয়া, ফসল ও মাঠের তথ্য আপনার এলাকার জন্য সাজাতে অবস্থান ঠিক করুন।'
      : 'Set your location to personalize weather, crops and field insights.';
  String get locatingFarm => isBangla
      ? 'ডিভাইস থেকে আপনার বর্তমান অবস্থান নেওয়া হচ্ছে…'
      : 'Getting your current device location…';
  String get locationFixed =>
      isBangla ? 'ডিভাইসের অবস্থান পাওয়া গেছে' : 'Device location found';
  String locationAccuracy(int meters) => isBangla
      ? 'আনুমানিক নির্ভুলতা: ±$meters মিটার। এটি আপনার খামার কি না নিশ্চিত করুন।'
      : 'Approximate accuracy: ±$meters m. Confirm this is your farm.';
  String get areaOrDistrictHint => isBangla
      ? 'আপনার এলাকার নাম লিখুন বা নিশ্চিত করুন'
      : 'Enter or confirm your area name';
  String get useMyLocation =>
      isBangla ? 'আমার অবস্থান ব্যবহার করুন' : 'Use My Location';
  String get chooseManually => isBangla ? 'নিজে বেছে নিন' : 'Choose Manually';
  String get useGpsInstead =>
      isBangla ? 'বদলে GPS অবস্থান ব্যবহার করুন' : 'Use GPS location instead';
  String get typeDifferentArea =>
      isBangla ? 'অন্য এলাকা লিখুন' : 'Type a different area';
  String get locationChangeAnytime => isBangla
      ? 'এটি পরে যেকোনো সময় বদলাতে পারবেন।'
      : 'You can change this anytime.';
  String get locationPermissionDenied => isBangla
      ? 'অবস্থানের অনুমতি পাওয়া যায়নি। নিচে নিজে এলাকা লিখুন।'
      : 'Location permission was not granted. Type your area below.';
  String get locationServiceOff => isBangla
      ? 'ডিভাইসের লোকেশন সেবা বন্ধ আছে। চালু করুন বা নিজে এলাকা লিখুন।'
      : 'Device location is off. Turn it on or type your area.';
  String get locationUnavailable => isBangla
      ? 'এখন অবস্থান পাওয়া যাচ্ছে না। নিচে নিজে এলাকা লিখুন।'
      : 'Location is unavailable right now. Type your area below.';

  // ---- Onboarding: farm info step ----
  String get aboutYourFarm =>
      isBangla ? 'আপনার খামার সম্পর্কে' : 'About your farm';
  String get farmInfoPrivacy => isBangla
      ? 'এই তথ্য শুধু আপনার ডিভাইসে রাখা হয়।'
      : 'This information is stored only on your device.';
  String get yourName => isBangla ? 'আপনার নাম' : 'Your name';
  String get yourNameHint => isBangla ? 'যেমন: নিলয়' : 'e.g. Rahim';
  String get farmSize => isBangla ? 'জমির পরিমাণ' : 'Farm size';
  String get farmSizeHint => isBangla ? 'যেমন: ২.৫' : 'e.g. 2.5';
  String get acreUnit => isBangla ? 'একর' : 'acres';
  String get farmSizeInvalid => isBangla
      ? 'একটি সঠিক সংখ্যা লিখুন (ইংরেজি অঙ্কে)।'
      : 'Enter a valid number.';
  String get currentCropQuestion =>
      isBangla ? 'এখন কোন ফসল আছে?' : 'What crop is growing now?';

  /// Display name for a crop. The stored value is the Bangla name, which is
  /// kept unchanged; only the label is localized.
  String cropName(String stored) {
    if (isBangla) return stored;
    return _cropEnglish[stored] ?? stored;
  }

  static const _cropEnglish = <String, String>{
    'বোরো ধান': 'Boro rice',
    'আমন ধান': 'Aman rice',
    'গম': 'Wheat',
    'ভুট্টা': 'Maize',
    'আলু': 'Potato',
    'পাট': 'Jute',
    'সরিষা': 'Mustard',
    'টমেটো': 'Tomato',
  };

  // ---- Onboarding: field step ----
  String get markYourField =>
      isBangla ? 'আপনার জমি চিহ্নিত করুন' : 'Mark your field';
  String get markFieldSubtitle => isBangla
      ? 'মানচিত্রে জমির সীমানা এঁকে দিলে মাঠভিত্তিক তথ্য দেখানো সহজ হয়।'
      : 'Drawing the field boundary on the map makes field-level insights easier to show.';
  String get skipForNow => isBangla ? 'এখন বাদ দিন' : 'Skip for now';
  String get previousCropQuestion => isBangla
      ? 'আগের মৌসুমে কী ছিল? (ঐচ্ছিক)'
      : 'What was grown last season? (optional)';
  String get soilTypeQuestion =>
      isBangla ? 'মাটির ধরন (ঐচ্ছিক)' : 'Soil type (optional)';
  String get soilClay => isBangla ? 'এঁটেল' : 'Clay';
  String get soilLoam => isBangla ? 'দোআঁশ' : 'Loam';
  String get soilSandy => isBangla ? 'বেলে' : 'Sandy';
  String get soilSilt => isBangla ? 'পলি' : 'Silt';
  String get soilUnknown => isBangla ? 'জানা নেই' : 'Not sure';
  String pointCount(int count) => isBangla
      ? '$count টি বিন্দু'
      : '$count ${count == 1 ? 'point' : 'points'}';
  String get boundaryDrawn =>
      isBangla ? 'সীমানা আঁকা হয়েছে' : 'Boundary drawn';
  String get boundaryNotDrawn =>
      isBangla ? 'সীমানা আঁকা হয়নি' : 'Boundary not drawn';
  String get canRedrawBoundary => isBangla
      ? 'চাইলে আবার এঁকে বদলাতে পারেন।'
      : 'You can redraw it if you like.';
  String get tapMapToDraw => isBangla
      ? 'মানচিত্রে ট্যাপ করে জমির কোণগুলো চিহ্নিত করুন।'
      : 'Tap the map to mark the field corners.';
  String get redrawBoundary => isBangla ? 'আবার' : 'Redraw';
  String get drawBoundary => isBangla ? 'আঁকুন' : 'Draw';

  // ---- Onboarding: goal step ----
  String get mainGoalQuestion =>
      isBangla ? 'আপনার মূল লক্ষ্য কী?' : 'What is your main goal?';
  String get goalSubtitle => isBangla
      ? 'যেটি বেছে নেবেন, পরামর্শ সেদিকেই বেশি জোর দেবে।'
      : 'Advice will focus most on the goal you choose.';
  String get finishSetup => isBangla ? 'শেষ করুন' : 'Finish';
  String get goalSaveWater => isBangla ? 'পানি সাশ্রয়' : 'Save water';
  String get goalSaveWaterHint =>
      isBangla ? 'সেচ কমিয়ে খরচ বাঁচান' : 'Cut irrigation costs';
  String get goalIncreaseYield => isBangla ? 'ফলন বাড়ানো' : 'Increase yield';
  String get goalIncreaseYieldHint =>
      isBangla ? 'একই জমিতে বেশি উৎপাদন' : 'More output from the same field';
  String get goalImproveSoil => isBangla ? 'মাটির উন্নতি' : 'Improve soil';
  String get goalImproveSoilHint =>
      isBangla ? 'মাটির স্বাস্থ্য ফিরিয়ে আনুন' : 'Restore soil health';
  String get goalClimateRisk =>
      isBangla ? 'আবহাওয়ার ঝুঁকি কমানো' : 'Reduce weather risk';
  String get goalClimateRiskHint =>
      isBangla ? 'ঝড়-বৃষ্টির ক্ষতি এড়ান' : 'Avoid storm and rain damage';
  String get goalNextCrop =>
      isBangla ? 'পরের ফসল ঠিক করা' : 'Choose the next crop';
  String get goalNextCropHint =>
      isBangla ? 'কী লাগাবেন সিদ্ধান্ত নিন' : 'Decide what to plant';

  // ---- Authentication ----
  String get account => isBangla ? 'অ্যাকাউন্ট' : 'Account';
  String get authTitleLogin => isBangla ? 'লগ ইন' : 'Log in';
  String get authTitleRegister =>
      isBangla ? 'অ্যাকাউন্ট তৈরি করুন' : 'Create account';
  String get authHeadingLogin => isBangla ? 'স্বাগতম' : 'Welcome back';
  String get authHeadingRegister =>
      isBangla ? 'আপনার অ্যাকাউন্ট তৈরি করুন' : 'Create your account';
  String get authSubtitle => isBangla
      ? 'আপনার খামারের ডেটা নিরাপদে সংরক্ষণ করতে ইমেল দিয়ে লগ ইন করুন।'
      : 'Sign in with your email to securely sync and store your farm data.';
  String get authEmailLabel => isBangla ? 'ইমেল ঠিকানা' : 'Email address';
  String get authCodeLabel =>
      isBangla ? '৬ ডিজিটের ইমেল কোড' : '6-digit email code';
  String get authSendCode =>
      isBangla ? 'ইমেল কোড পাঠান' : 'Send email code';
  String get authVerifyAndContinue =>
      isBangla ? 'যাচাই করে এগিয়ে যান' : 'Verify and continue';
  String get authPleaseWait =>
      isBangla ? 'অনুগ্রহ করে অপেক্ষা করুন…' : 'Please wait…';
  String get authSwitchToLogin => isBangla
      ? 'ইতিমধ্যে অ্যাকাউন্ট আছে? লগ ইন করুন'
      : 'Already have an account? Log in';
  String get authSwitchToRegister => isBangla
      ? 'নতুন ব্যবহারকারী? অ্যাকাউন্ট তৈরি করুন'
      : 'New here? Create account';
  String get authRequestAnotherCode =>
      isBangla ? 'আরেকটি কোড পাঠান' : 'Request another code';
  String authResendInSeconds(int seconds) => isBangla
      ? '${digits(seconds)} সেকেন্ড পর পুনরায় কোড চাওয়া যাবে'
      : 'Request another code in ${seconds}s';
  String get authFirebaseNotConfigured => isBangla
      ? 'এই বিল্ডে Firebase কনফিগার করা নেই।'
      : 'Firebase is not configured for this build.';
  String get authEnterEmailError =>
      isBangla ? 'আপনার ইমেল ঠিকানা লিখুন' : 'Enter your email address';
  String get authInvalidEmailError => isBangla
      ? 'একটি কার্যকর ইমেল ঠিকানা লিখুন'
      : 'Enter a valid email address';
  String get authEnterCodeError =>
      isBangla ? '৬ ডিজিটের কোডটি লিখুন' : 'Enter the 6-digit code';
  String get authFailedError => isBangla
      ? 'অথেনটিকেশন ব্যর্থ হয়েছে। অনুগ্রহ করে আবার চেষ্টা করুন।'
      : 'Authentication failed. Please try again.';
  String get authNetworkError => isBangla
      ? 'সার্ভারের সাথে সংযোগ স্থাপন করা যায়নি'
      : 'Could not connect to the server';
  String get authCodeSentNotice => isBangla
      ? 'আপনার ইমেলে একটি ৬ ডিজিটের কোড পাঠানো হয়েছে'
      : 'A 6-digit code has been sent to your email';
  String get authDemoModeAction =>
      isBangla ? 'ডেমো মোডে প্রবেশ করুন' : 'Explore in Demo Mode';
  String get authDemoModeNote => isBangla
      ? 'ডেমো মোড: অফলাইন ও ডেমো ফিচারগুলো দেখতে পারেন।'
      : 'Demo mode: You can explore offline & demo features.';

  // ---- Onboarding: analysis step ----
  List<String> get analysisSteps => isBangla
      ? const [
          'আপনার এলাকা মিলিয়ে নেওয়া হচ্ছে',
          'মাঠের তথ্য সাজানো হচ্ছে',
          'আবহাওয়ার ঝুঁকি প্রস্তুত করা হচ্ছে',
          'আপনার ড্যাশবোর্ড তৈরি হচ্ছে',
        ]
      : const [
          'Matching your area',
          'Arranging field details',
          'Preparing weather risks',
          'Building your dashboard',
        ];
  String get preparingFarm =>
      isBangla ? 'আপনার মাঠ প্রস্তুত করা হচ্ছে' : 'Preparing your farm';
  String get preparingDashboardEyebrow =>
      isBangla ? 'ড্যাশবোর্ড প্রস্তুত হচ্ছে' : 'PREPARING YOUR DASHBOARD';
  String get analysisDemoNote => isBangla
      ? 'এটি একটি ডেমো ট্রানজিশন — এখানে কোনো লাইভ স্যাটেলাইট বা আবহাওয়া হিসাব করা হচ্ছে না।'
      : 'This is a demo transition. No live satellite or weather calculation is running here.';
}

/// `context.l10n` - shorthand for [AppLocalizations.of].
extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(
      AppLocalizations.forLocale(locale),
    );
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
