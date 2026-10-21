import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_si.dart';
import 'app_localizations_ta.dart';

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
    Locale('si'),
    Locale('ta'),
  ];

  /// The title of the main feed screen
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// Hint text shown inside the search bar
  ///
  /// In en, this message translates to:
  /// **'Search requests, items, services...'**
  String get searchHint;

  /// Header for the section showing ongoing user requests
  ///
  /// In en, this message translates to:
  /// **'ACTIVE REQUESTS'**
  String get activeRequests;

  /// Column title for requests the user has accepted
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get accepted;

  /// Column title for requests the user has posted
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get posted;

  /// Text shown when a request column is empty
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// Header for the user's personal activity feed
  ///
  /// In en, this message translates to:
  /// **'YOUR RECENT ACTIVITY'**
  String get recentActivity;

  /// Header for the public community activity feed
  ///
  /// In en, this message translates to:
  /// **'COMMUNITY ACTIVITY'**
  String get communityActivity;

  /// Good morning greeting
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get goodMorning;

  /// Good afternoon greeting
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon'**
  String get goodAfternoon;

  /// Good evening greeting
  ///
  /// In en, this message translates to:
  /// **'Good Evening'**
  String get goodEvening;

  /// Bottom navigation Feed label
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get navFeed;

  /// Bottom navigation Map label
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// Bottom navigation Chat label
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// Bottom navigation Account label
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get navAccount;

  /// Profile screen title
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// Activity & Reputation section header
  ///
  /// In en, this message translates to:
  /// **'Activity & Reputation'**
  String get profileActivityHeader;

  /// Preferences section header
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get profilePreferencesHeader;

  /// Support & Security section header
  ///
  /// In en, this message translates to:
  /// **'Support & Security'**
  String get profileSupportHeader;

  /// Aura & Circl Points settings tile
  ///
  /// In en, this message translates to:
  /// **'Aura & Circl Points'**
  String get profileAuraPointsTile;

  /// My Posted Requests settings tile
  ///
  /// In en, this message translates to:
  /// **'My Posted Requests'**
  String get profilePostedRequestsTile;

  /// Accepted Requests settings tile
  ///
  /// In en, this message translates to:
  /// **'Accepted Requests'**
  String get profileAcceptedRequestsTile;

  /// My Reviews settings tile
  ///
  /// In en, this message translates to:
  /// **'My Reviews'**
  String get profileReviewsTile;

  /// Dark Mode settings tile
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get profileDarkModeTile;

  /// Language settings tile
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileLanguageTile;

  /// Biometrics settings tile
  ///
  /// In en, this message translates to:
  /// **'Face ID / Biometrics'**
  String get profileBiometricsTile;

  /// Biometrics settings tile subtitle
  ///
  /// In en, this message translates to:
  /// **'Verify identity for payments'**
  String get profileBiometricsSubtitle;

  /// Dispute Center settings tile
  ///
  /// In en, this message translates to:
  /// **'Dispute Center'**
  String get profileDisputeTile;

  /// Help & FAQ settings tile
  ///
  /// In en, this message translates to:
  /// **'Help & FAQ'**
  String get profileHelpFAQTile;

  /// Privacy Policy settings tile
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get profilePrivacyTile;

  /// Logout settings tile
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get profileLogoutTile;

  /// Select Language picker title
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get profileSelectLanguage;

  /// English language label
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get profileEnglish;

  /// Sinhala language label
  ///
  /// In en, this message translates to:
  /// **'සිංහල (Sinhala)'**
  String get profileSinhala;

  /// Tamil language label
  ///
  /// In en, this message translates to:
  /// **'தமிழ் (Tamil)'**
  String get profileTamil;

  /// Label on map screen showing request count
  ///
  /// In en, this message translates to:
  /// **'requests in this area'**
  String get mapRequestsCount;

  /// View button label on map request sheet
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get mapViewButton;

  /// Chat button label on map request sheet
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get mapChatButton;

  /// Chats screen title
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatsTitle;

  /// Search hint in chats screen
  ///
  /// In en, this message translates to:
  /// **'Search conversations...'**
  String get chatsSearchHint;

  /// Empty state label on chats screen
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get chatsNoConversations;

  /// Filter option All
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// Filter option Unread
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get filterUnread;

  /// Filter option Active
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get filterActive;

  /// Filter option Completed
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get filterCompleted;

  /// Feed filter sheet title
  ///
  /// In en, this message translates to:
  /// **'FILTER & SORT'**
  String get feedFilterSortTitle;

  /// Feed filter distance header
  ///
  /// In en, this message translates to:
  /// **'Maximum Distance'**
  String get feedFilterMaxDistance;

  /// Feed filter rating header
  ///
  /// In en, this message translates to:
  /// **'Minimum Rating'**
  String get feedFilterMinRating;

  /// Feed filter date sort header
  ///
  /// In en, this message translates to:
  /// **'Sort By Date'**
  String get feedFilterSortByDate;

  /// Feed filter alphabetical sort header
  ///
  /// In en, this message translates to:
  /// **'Sort Alphabetically'**
  String get feedFilterSortAlpha;

  /// Feed filter apply button label
  ///
  /// In en, this message translates to:
  /// **'Apply & View Results'**
  String get feedFilterApply;

  /// Feed filter Any rating option label
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get feedFilterAny;

  /// Feed filter Sort option Newest to Oldest
  ///
  /// In en, this message translates to:
  /// **'Newest to Oldest'**
  String get feedFilterNewest;

  /// Feed filter Sort option Oldest to Newest
  ///
  /// In en, this message translates to:
  /// **'Oldest to Newest'**
  String get feedFilterOldest;

  /// Feed filter Sort option A to Z
  ///
  /// In en, this message translates to:
  /// **'A to Z'**
  String get feedFilterAtoZ;

  /// Feed filter Sort option Z to A
  ///
  /// In en, this message translates to:
  /// **'Z to A'**
  String get feedFilterZtoA;

  /// Feed filter Sort option None
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get feedFilterNone;

  /// Create request screen title
  ///
  /// In en, this message translates to:
  /// **'Create Request'**
  String get postTitle;

  /// Create request screen section question
  ///
  /// In en, this message translates to:
  /// **'What do you need?'**
  String get postQuestion;

  /// Create request details header
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get postDetails;

  /// Create request expected duration header
  ///
  /// In en, this message translates to:
  /// **'Expected Duration'**
  String get postDuration;

  /// Create request maximum budget header
  ///
  /// In en, this message translates to:
  /// **'Maximum Budget'**
  String get postBudget;

  /// Create request security deposit limit header
  ///
  /// In en, this message translates to:
  /// **'Security Deposit Limit'**
  String get postDeposit;

  /// Create request delivery format section header
  ///
  /// In en, this message translates to:
  /// **'How do you need this done?'**
  String get postHowDone;

  /// Create request location section header
  ///
  /// In en, this message translates to:
  /// **'Where do you need this?'**
  String get postWhereDone;

  /// Create request location type current location label
  ///
  /// In en, this message translates to:
  /// **'Current Location'**
  String get postCurrentLocation;

  /// Create request save address button label
  ///
  /// In en, this message translates to:
  /// **'Save Address'**
  String get postSaveAddress;

  /// Create request cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get postCancel;

  /// Create request saved locations label
  ///
  /// In en, this message translates to:
  /// **'Saved Locations'**
  String get postSavedLocations;

  /// Create request tap to detect location instruction
  ///
  /// In en, this message translates to:
  /// **'Tap to detect location'**
  String get postDetectLocation;

  /// Create request payment protection title
  ///
  /// In en, this message translates to:
  /// **'Payment Protection'**
  String get postEscrowTitle;

  /// Create request payment protection description
  ///
  /// In en, this message translates to:
  /// **'Payment held in escrow. Released only when you confirm completion.'**
  String get postEscrowDesc;

  /// Account section header
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileAccountHeader;

  /// Edit Profile tile label
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEditProfile;

  /// Identity Verification tile label
  ///
  /// In en, this message translates to:
  /// **'Identity Verification'**
  String get profileIdentityVerification;

  /// Toast message when identity is already verified
  ///
  /// In en, this message translates to:
  /// **'Your identity is already verified.'**
  String get profileIdentityVerifiedToast;

  /// Toast message when identity verification is pending review
  ///
  /// In en, this message translates to:
  /// **'Your verification is pending review.'**
  String get profileIdentityPendingToast;

  /// Location & Address tile label
  ///
  /// In en, this message translates to:
  /// **'Location & Address'**
  String get profileLocationAddress;

  /// Wallet tile label
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get profileWallet;

  /// Header label for nearby requests
  ///
  /// In en, this message translates to:
  /// **'Nearby Requests'**
  String get feedNearbyRequests;

  /// Header label when no requests are found
  ///
  /// In en, this message translates to:
  /// **'No Requests Found'**
  String get feedNoRequestsFound;

  /// Label for request title input
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get postFieldTitle;

  /// Hint text for request title input
  ///
  /// In en, this message translates to:
  /// **'e.g., Need a pressure washer'**
  String get postFieldTitleHint;

  /// Label for request description input
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get postFieldDescription;

  /// Hint text for request description input
  ///
  /// In en, this message translates to:
  /// **'Describe condition, requirements...'**
  String get postFieldDescHint;

  /// Range picker section title
  ///
  /// In en, this message translates to:
  /// **'How far are you searching?'**
  String get postSearchRangeTitle;

  /// Review request details header title
  ///
  /// In en, this message translates to:
  /// **'Review Details'**
  String get postReviewDetailsTitle;

  /// Search input placeholder on map screen
  ///
  /// In en, this message translates to:
  /// **'Search nearby...'**
  String get mapSearchNearby;

  /// Placeholder on map screen search when empty
  ///
  /// In en, this message translates to:
  /// **'No requests available'**
  String get mapNoRequestsAvailable;
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
      <String>['en', 'si', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'si':
      return AppLocalizationsSi();
    case 'ta':
      return AppLocalizationsTa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
