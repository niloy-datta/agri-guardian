/// One screen's spoken guide, in Bangla and English.
///
/// [matchPattern] is matched against the current route path. [lines] (Bangla)
/// and [linesEn] (English) are spoken in order, in the language the user has
/// selected. [navPath] is set only for screens the full tour visits; it is the
/// concrete path the tour navigates to. [inShell] means the screen sits under
/// the bottom nav, so the floating voice button is raised above it.
class GuideScreen {
  const GuideScreen({
    required this.title,
    required this.titleEn,
    required this.matchPattern,
    required this.lines,
    required this.linesEn,
    this.navPath,
    this.inShell = false,
  });

  final String title;
  final String titleEn;
  final String matchPattern;
  final List<String> lines;
  final List<String> linesEn;
  final String? navPath;
  final bool inShell;

  bool matches(String path) => RegExp(matchPattern).hasMatch(path);

  String titleFor({required bool isBangla}) => isBangla ? title : titleEn;

  List<String> linesFor({required bool isBangla}) => isBangla ? lines : linesEn;
}

/// Every screen the voice guide can describe. Order matters only for the
/// full tour, which walks the entries that have a [GuideScreen.navPath].
const List<GuideScreen> screenGuides = [
  // ---------- Authentication ----------
  GuideScreen(
    title: 'লগইন ও নিবন্ধন',
    titleEn: 'Sign In & Register',
    matchPattern: r'^/auth$',
    lines: [
      'এটি লগইন ও অ্যাকাউন্ট খোলার পাতা।',
      'আপনার ইমেল ঠিকানা লিখে কোড পাঠানোর বোতামে চাপ দিন।',
      'ইমেলে পাওয়া ছয় ডিজিটের কোডটি লিখে যাচাই করে এগিয়ে যান।',
    ],
    linesEn: [
      'This is the sign in and registration page.',
      'Enter your email address and press the send code button.',
      'Enter the six-digit code received in your email to verify and continue.',
    ],
  ),

  // ---------- First-run setup ----------
  GuideScreen(
    title: 'খামারের অবস্থান',
    titleEn: 'Farm location',
    matchPattern: r'^/onboarding/location$',
    lines: [
      'এটি প্রথম ধাপ: খামারের অবস্থান ঠিক করুন।',
      'অবস্থানের অনুমতি দিলে অ্যাপ নিজে থেকে আপনার এলাকা খুঁজে নেবে।',
      'ঠিক থাকলে নিচের বোতামে চাপ দিয়ে পরের ধাপে যান।',
    ],
    linesEn: [
      'This is the first step: set your farm location.',
      'If you allow location access, the app will find your area by itself.',
      'When it looks right, press the button below to go to the next step.',
    ],
  ),
  GuideScreen(
    title: 'ভাষা নির্বাচন',
    titleEn: 'Choose language',
    matchPattern: r'^/onboarding/language$',
    lines: [
      'এখন ভাষা বেছে নিন।',
      'বাংলা বা ইংরেজির একটি বেছে নিলে পুরো অ্যাপ সেই ভাষায় দেখাবে।',
      'তারপর নিচের বোতামে চাপ দিয়ে পরের ধাপে যান।',
    ],
    linesEn: [
      'Now choose your language.',
      'Pick Bangla or English and the whole app will show in that language.',
      'Then press the button below to go to the next step.',
    ],
  ),
  GuideScreen(
    title: 'খামারের তথ্য',
    titleEn: 'Farm details',
    matchPattern: r'^/onboarding/farm$',
    lines: [
      'এখন খামারের তথ্য লিখুন।',
      'শেষ হলে নিচের বোতামে চাপ দিয়ে পরের ধাপে যান।',
      'আগের ধাপে ফিরতে পেছনের বোতাম ব্যবহার করুন।',
    ],
    linesEn: [
      'Now enter your farm details.',
      'When you are done, press the button below to go to the next step.',
      'To go back to the previous step, use the back button.',
    ],
  ),
  GuideScreen(
    title: 'প্রথম জমি',
    titleEn: 'First field',
    matchPattern: r'^/onboarding/field$',
    lines: [
      'এখন আপনার প্রথম জমির তথ্য দিন।',
      'জমির নাম, এলাকা ও সীমানা ঠিক করুন।',
      'পরে আরও জমি যোগ করতে পারবেন।',
    ],
    linesEn: [
      'Now enter the details of your first field.',
      'Set the field name, area and boundary.',
      'You can add more fields later.',
    ],
  ),
  GuideScreen(
    title: 'আপনার লক্ষ্য',
    titleEn: 'Your goal',
    matchPattern: r'^/onboarding/goal$',
    lines: [
      'আপনার প্রধান লক্ষ্য বেছে নিন।',
      'যেমন ফসলের স্বাস্থ্য দেখা, রোগ শনাক্ত করা, বা সেচের পরিকল্পনা।',
      'নিচের বোতামে চাপ দিলে অ্যাপ আপনার তথ্য বিশ্লেষণ শুরু করবে।',
    ],
    linesEn: [
      'Choose your main goal.',
      'For example, checking crop health, detecting disease, or planning irrigation.',
      'Press the button below and the app will start analysing your details.',
    ],
  ),
  GuideScreen(
    title: 'বিশ্লেষণ',
    titleEn: 'Analysis',
    matchPattern: r'^/onboarding/analysis$',
    lines: [
      'অ্যাপ এখন আপনার তথ্য বিশ্লেষণ করছে।',
      'বিশ্লেষণ শেষ হলে নিজে থেকেই হোম পাতায় চলে যাবে।',
    ],
    linesEn: [
      'The app is now analysing your details.',
      'When the analysis is done, it will open the home page by itself.',
    ],
  ),

  // ---------- Main tabs (bottom nav) ----------
  GuideScreen(
    title: 'হোম পাতা',
    titleEn: 'Home page',
    matchPattern: r'^/$',
    navPath: '/',
    inShell: true,
    lines: [
      'আপনি এখন হোম পাতায় আছেন। এখানে আবহাওয়া, আপনার জমির অবস্থা, এবং দ্রুত কাজের বোতাম রয়েছে।',
      'গাছের রোগ শনাক্ত করতে স্ক্যান প্ল্যান্ট বোতামে চাপ দিন।',
      'আবহাওয়ার পূর্বাভাস দেখতে আবহাওয়া বোতামে, বাজার দর দেখতে মার্কেট প্রাইস বোতামে, আর কৃষি সহকারীকে প্রশ্ন করতে এক্সপার্ট হেল্প বোতামে চাপ দিন।',
      'নিচের মেনুতে বাঁ দিক থেকে আছে: হোম, আমার জমি, মাঝখানের গোল স্ক্যান বোতাম, ইনসাইট, এবং প্রোফাইল।',
    ],
    linesEn: [
      'You are on the home page. Here you can see the weather, the condition of your field, and quick action buttons.',
      'To detect plant disease, press the Scan Plant button.',
      'To see the weather forecast, press Weather. For market prices, press Market Price. To ask the farm assistant, press Expert Help.',
      'The bottom menu, from left: Home, My Fields, the round Scan button in the middle, Insights, and Profile.',
    ],
  ),
  GuideScreen(
    title: 'আমার জমি',
    titleEn: 'My fields',
    matchPattern: r'^/fields$',
    navPath: '/fields',
    inShell: true,
    lines: [
      'এখন আপনি আমার জমি পাতায় আছেন। এখানে আপনার সব জমির তালিকা, মোট একর, এবং প্রতিটি জমির অবস্থা দেখা যায়।',
      'নতুন জমি যোগ করতে জমি যোগ করুন বোতামে চাপ দিন। তারপর জমির তথ্য লিখে সংরক্ষণ করুন।',
      'কোনো জমির কার্ডে চাপ দিলে তার বিস্তারিত পাতা খুলবে।',
      'ইন্টারনেট না থাকলেও জমি সংরক্ষিত থাকবে। সংযোগ ফিরলে সিঙ্কের অপেক্ষায় থাকা পরিবর্তন পাঠাতে এখন সিঙ্ক করুন বোতামে চাপ দিন।',
    ],
    linesEn: [
      'You are on the My Fields page. Here you can see all your fields, the total acreage, and the status of each field.',
      'To add a new field, press Add field, then enter the field details and save.',
      'Tap any field card to open its details.',
      'Fields are kept even without internet. When the connection returns, press Sync now to send changes that are waiting.',
    ],
  ),
  GuideScreen(
    title: 'জমির বিস্তারিত',
    titleEn: 'Field details',
    matchPattern: r'^/field-details/[^/]+$',
    lines: [
      'এটি একটি নির্দিষ্ট জমির বিস্তারিত পাতা। এখানে জমির এলাকা, সীমানা, ও স্বাস্থ্যের তথ্য দেখানো হয়।',
      'আগের পাতায় ফিরতে উপরের পেছনের তীর চিহ্নে চাপ দিন।',
    ],
    linesEn: [
      'This is the details page of one field. It shows the area, boundary and health information.',
      'To go back to the previous page, press the back arrow at the top.',
    ],
  ),
  GuideScreen(
    title: 'ইনসাইট',
    titleEn: 'Insights',
    matchPattern: r'^/field-insights$',
    navPath: '/field-insights',
    inShell: true,
    lines: [
      'আপনি এখন ইনসাইট পাতায় আছেন। এখানে জমির সামগ্রিক অবস্থা ও সবচেয়ে গুরুত্বপূর্ণ সতর্কতা দেখানো হয়।',
      'আজ কী করতে হবে, তা সবচেয়ে গুরুত্বপূর্ণ অংশে লেখা থাকে। সেচ সংক্রান্ত সতর্কতাও এখানে পাবেন।',
      'জমির স্যাটেলাইট ম্যাপ দেখতে স্যাটেলাইট ম্যাপ দেখুন বোতামে চাপ দিন।',
    ],
    linesEn: [
      'You are on the Insights page. It shows the overall condition of your field and the most important warnings.',
      'What to do today is shown in the most important section. Irrigation warnings are here too.',
      'To see the satellite map of the field, press View satellite map.',
    ],
  ),
  GuideScreen(
    title: 'স্যাটেলাইট ম্যাপ',
    titleEn: 'Satellite map',
    matchPattern: r'^/field-insights/satellite-analysis$',
    navPath: '/field-insights/satellite-analysis',
    inShell: true,
    lines: [
      'এটি স্যাটেলাইট বিশ্লেষণ পাতা। এখানে জমির ম্যাপে গাছের সবুজ অবস্থার তথ্য দেখানো হয়।',
      'ইনসাইট পাতায় ফিরতে নিচের মেনুতে ইনসাইট ট্যাবে চাপ দিন।',
    ],
    linesEn: [
      'This is the satellite analysis page. The field map shows how green the crops are.',
      'To go back to Insights, press the Insights tab in the bottom menu.',
    ],
  ),
  GuideScreen(
    title: 'প্রোফাইল',
    titleEn: 'Profile',
    matchPattern: r'^/profile$',
    navPath: '/profile',
    inShell: true,
    lines: [
      'আপনি এখন প্রোফাইল পাতায় আছেন। এখানে খামারের পরিসংখ্যান দেখা যায়: মোট একর, গড় স্বাস্থ্য, এবং স্ক্যানের সংখ্যা।',
      'সেটিংসের তালিকায় ভাষা, নোটিফিকেশন, খামারের অবস্থান, এবং সেচের সেটিংস পাবেন।',
      'আপনার ফসল বিক্রি করতে মার্কেটপ্লেসে বিক্রি করুন বোতামে চাপ দিন।',
    ],
    linesEn: [
      'You are on the Profile page. It shows your farm statistics: total acres, average health and the number of scans.',
      'The settings list includes language, notifications, farm location and irrigation settings.',
      'To sell your crop, press Sell on marketplace.',
    ],
  ),

  // ---------- Pages opened from Home ----------
  GuideScreen(
    title: 'আবহাওয়া',
    titleEn: 'Weather',
    matchPattern: r'^/weather$',
    navPath: '/weather',
    inShell: true,
    lines: [
      'এটি আবহাওয়া পাতা। এখানে আপনার এলাকার আগামী সাত দিনের পূর্বাভাস দেখা যাবে।',
      'আবহাওয়ার কারণে ফসলের কোনো ঝুঁকি আছে কি না, তা আবহাওয়া ঝুঁকি কেন্দ্র অংশে দেখানো হয়।',
      'পূর্বাভাসের তথ্যের উৎস জানতে নিচের তথ্য ও উৎস অংশটি দেখুন।',
    ],
    linesEn: [
      'This is the weather page. It shows the seven-day forecast for your area.',
      'Whether the weather poses any risk to your crop is shown in the Weather Risk Center section.',
      'To see where the forecast data comes from, look at the Data and evidence section below.',
    ],
  ),
  GuideScreen(
    title: 'বাজার দর',
    titleEn: 'Market prices',
    matchPattern: r'^/market-price$',
    navPath: '/market-price',
    inShell: true,
    lines: [
      'এখানে বাজার দর, দামের প্রবণতা, এবং এআই বিক্রয় পরামর্শ দেখানো হয়।',
      'এই দরগুলো এখনো ডেমো নমুনা। বিক্রির সিদ্ধান্ত নেওয়ার আগে স্থানীয় বাজার যাচাই করুন।',
      'দামের গতিবিধি দেখতে মূল্য প্রবণতা চার্ট দেখুন।',
    ],
    linesEn: [
      'Here you can see market prices, price trends and AI selling advice.',
      'These prices are still demo samples. Check your local market before you decide to sell.',
      'To see how prices move, look at the price trend chart.',
    ],
  ),
  GuideScreen(
    title: 'কৃষি সহকারী',
    titleEn: 'Farm assistant',
    matchPattern: r'^/ai-assistant$',
    navPath: '/ai-assistant',
    inShell: true,
    lines: [
      'এটি এআই কৃষি সহকারী। এখানে প্রশ্ন লিখলে উত্তর পাওয়া যায়।',
      'নিচের প্রশ্ন লেখার ঘরে প্রশ্ন টাইপ করুন, তারপর পাঠানোর চিহ্নে চাপ দিন। উদাহরণ: আজ সেচ দেব কি না?',
      'এখনো লাইভ এআই যুক্ত হয়নি, তাই উত্তরগুলো ডেমো নমুনা হিসেবে দেখানো হচ্ছে। মাইক বোতামে কথা বলার সুবিধাও এখনো চালু হয়নি।',
    ],
    linesEn: [
      'This is the AI farm assistant. Type a question and you will get an answer.',
      'Type your question in the box below, then press send. For example: should I irrigate today?',
      'A live AI is not connected yet, so the answers are demo samples. Speaking with the microphone button is not available yet either.',
    ],
  ),

  // ---------- Focused screens (no bottom nav) ----------
  GuideScreen(
    title: 'ফসল স্ক্যান',
    titleEn: 'Scan plant',
    matchPattern: r'^/scan$',
    navPath: '/scan',
    lines: [
      'এটি স্ক্যান পাতা। গাছের আক্রান্ত পাতার ছবি তুলে রোগ শনাক্ত করা যায়।',
      'ছবি তোলার আগে: আক্রান্ত পাতার ওপর ক্যামেরা স্থির রাখুন। পর্যাপ্ত আলোতে ছবি তুলুন। শুধু একটি পাতায় ফোকাস করুন। আঙুল বা ছায়া দিয়ে পাতা ঢেকে রাখবেন না।',
      'প্রস্তুত হলে ছবি তোলার বোতামে চাপ দিন।',
    ],
    linesEn: [
      'This is the scan page. Take a photo of an affected leaf to detect the disease.',
      'Before you take the photo: hold the camera steady over the affected leaf. Use good daylight. Focus on one leaf only. Do not cover the leaf with your finger or a shadow.',
      'When you are ready, press the capture button.',
    ],
  ),
  GuideScreen(
    title: 'রোগ শনাক্তের ফল',
    titleEn: 'Diagnosis result',
    matchPattern: r'^/scan-result$',
    lines: [
      'এখানে ছবি বিশ্লেষণের ফল দেখানো হয়। কোন রোগ শনাক্ত হয়েছে, এবং সেটি কতটা নিশ্চিত, তা লেখা থাকে।',
      'ঝুঁকির মাত্রা ও আস্থার হার ভালোভাবে দেখুন।',
      'ফসলের করণীয় জানতে পরবর্তী ধাপের বোতামে চাপ দিন।',
    ],
    linesEn: [
      'This page shows the result of the photo analysis. It says which disease was found and how confident the result is.',
      'Check the risk level and the confidence rate carefully.',
      'To see what to do for the crop, press the next-step button.',
    ],
  ),
  GuideScreen(
    title: 'চিকিৎসা পরিকল্পনা',
    titleEn: 'Treatment plan',
    matchPattern: r'^/treatment-plan$',
    lines: [
      'এখানে সাত দিনের ব্যবস্থাপনা পরিকল্পনা দেখানো হয়েছে। প্রতিটি ধাপ ক্রমানুসারে পড়ুন।',
      'কোনো ধাপের নির্দেশনা শুনতে, সেই ধাপের পাশের শুনুন বোতামে চাপ দিন।',
      'অডিও নির্দেশিকা চালু বা বন্ধ করতে অডিও সুইচ ব্যবহার করুন।',
      'ওষুধ বা মাত্রা প্রয়োগের আগে স্থানীয় কৃষি কর্মকর্তার পরামর্শ নিন। এটি ডেমো নমুনা পরামর্শ।',
    ],
    linesEn: [
      'This is the seven-day management plan. Read each step in order.',
      'To hear the instructions for a step, press the Listen button next to it.',
      'To turn the audio guide on or off, use the audio switch.',
      'Before you apply any medicine or dose, check with your local agriculture officer. This is a demo sample advice.',
    ],
  ),
  GuideScreen(
    title: 'সেচ',
    titleEn: 'Irrigation',
    matchPattern: r'^/irrigation$',
    lines: [
      'এটি সেচ পাতা। এখানে জমিতে কখন ও কতটা সেচ দিতে হবে, তার নির্দেশনা থাকে।',
    ],
    linesEn: [
      'This is the irrigation page. It tells you when and how much to irrigate the field.',
    ],
  ),
  GuideScreen(
    title: 'ফসল বিক্রির তালিকা',
    titleEn: 'Create listing',
    matchPattern: r'^/marketplace/create$',
    lines: [
      'এখানে আপনার ফসল বিক্রির জন্য নতুন তালিকা তৈরি করা যায়।',
      'ফসলের নাম, পরিমাণ, ও দাম সঠিকভাবে লিখুন।',
      'সব লেখা হলে নিচের বোতামে চাপ দিয়ে তালিকাটি জমা দিন।',
    ],
    linesEn: [
      'Here you can create a new listing to sell your crop.',
      'Enter the crop name, quantity and price correctly.',
      'When everything is filled in, press the button below to submit the listing.',
    ],
  ),
];

/// The screen whose guide applies to [path], or null when none is defined.
GuideScreen? guideForPath(String path) {
  for (final guide in screenGuides) {
    if (guide.matches(path)) return guide;
  }
  return null;
}

/// Screens visited, in order, by the full-app voice tour.
final List<GuideScreen> tourGuides = [
  for (final guide in screenGuides)
    if (guide.navPath != null) guide,
];
