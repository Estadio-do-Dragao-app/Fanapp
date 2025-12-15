import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

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
    Locale('pt'),
  ];

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get search;

  /// No description provided for @whereToQuestion.
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get whereToQuestion;

  /// No description provided for @seat.
  ///
  /// In en, this message translates to:
  /// **'Seat'**
  String get seat;

  /// No description provided for @wc.
  ///
  /// In en, this message translates to:
  /// **'WC'**
  String get wc;

  /// No description provided for @food.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get food;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// Message shown when an item is selected
  ///
  /// In en, this message translates to:
  /// **'Selected: {item}'**
  String selected(String item);

  /// No description provided for @tapToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap to select'**
  String get tapToSelect;

  /// No description provided for @chooseLocation.
  ///
  /// In en, this message translates to:
  /// **'Choose a location'**
  String get chooseLocation;

  /// No description provided for @chooseLocationButton.
  ///
  /// In en, this message translates to:
  /// **'Choose location'**
  String get chooseLocationButton;

  /// No description provided for @faster.
  ///
  /// In en, this message translates to:
  /// **'Faster'**
  String get faster;

  /// Time in minutes
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String minutes(int count);

  /// No description provided for @evacuation.
  ///
  /// In en, this message translates to:
  /// **'EVACUATION'**
  String get evacuation;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'MAP'**
  String get map;

  /// No description provided for @turnLeft.
  ///
  /// In en, this message translates to:
  /// **'Turn left'**
  String get turnLeft;

  /// No description provided for @turnRight.
  ///
  /// In en, this message translates to:
  /// **'Turn right'**
  String get turnRight;

  /// No description provided for @continueStraight.
  ///
  /// In en, this message translates to:
  /// **'Continue straight'**
  String get continueStraight;

  /// No description provided for @arriveAtDestination.
  ///
  /// In en, this message translates to:
  /// **'Arrive at destination'**
  String get arriveAtDestination;

  /// No description provided for @arrival.
  ///
  /// In en, this message translates to:
  /// **'arrival'**
  String get arrival;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get time;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get distance;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'destination'**
  String get destination;

  /// No description provided for @endRoute.
  ///
  /// In en, this message translates to:
  /// **'End Route'**
  String get endRoute;

  /// No description provided for @addTicket.
  ///
  /// In en, this message translates to:
  /// **'Add Ticket'**
  String get addTicket;

  /// No description provided for @scanTicketQR.
  ///
  /// In en, this message translates to:
  /// **'Scan Ticket QR Code'**
  String get scanTicketQR;

  /// No description provided for @ticketInfo.
  ///
  /// In en, this message translates to:
  /// **'Ticket Information'**
  String get ticketInfo;

  /// No description provided for @sector.
  ///
  /// In en, this message translates to:
  /// **'Sector'**
  String get sector;

  /// No description provided for @row.
  ///
  /// In en, this message translates to:
  /// **'Row'**
  String get row;

  /// No description provided for @gate.
  ///
  /// In en, this message translates to:
  /// **'Gate'**
  String get gate;

  /// No description provided for @ticketType.
  ///
  /// In en, this message translates to:
  /// **'Ticket Type'**
  String get ticketType;

  /// No description provided for @deleteTicket.
  ///
  /// In en, this message translates to:
  /// **'Delete Ticket'**
  String get deleteTicket;

  /// No description provided for @deleteTicketConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this ticket?'**
  String get deleteTicketConfirm;

  /// No description provided for @noTicketScanned.
  ///
  /// In en, this message translates to:
  /// **'No ticket scanned'**
  String get noTicketScanned;

  /// No description provided for @noTicketScannedMessage.
  ///
  /// In en, this message translates to:
  /// **'Please scan your ticket QR code to navigate to your seat.'**
  String get noTicketScannedMessage;

  /// No description provided for @scanNow.
  ///
  /// In en, this message translates to:
  /// **'Scan Now'**
  String get scanNow;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @firstAid.
  ///
  /// In en, this message translates to:
  /// **'First Aid'**
  String get firstAid;

  /// No description provided for @information.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get information;

  /// No description provided for @merchandising.
  ///
  /// In en, this message translates to:
  /// **'Merchandising'**
  String get merchandising;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @floor.
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get floor;

  /// No description provided for @heatmap.
  ///
  /// In en, this message translates to:
  /// **'Heat map'**
  String get heatmap;

  /// No description provided for @accessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get accessibility;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get connectionFailed;

  /// No description provided for @newDestinationFound.
  ///
  /// In en, this message translates to:
  /// **'NEW DESTINATION FOUND'**
  String get newDestinationFound;

  /// No description provided for @lessQueue.
  ///
  /// In en, this message translates to:
  /// **'{place} has less queue'**
  String lessQueue(String place);

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @durationMin.
  ///
  /// In en, this message translates to:
  /// **'{time}'**
  String durationMin(String time);

  /// No description provided for @distanceM.
  ///
  /// In en, this message translates to:
  /// **'{dist} m'**
  String distanceM(int dist);

  /// No description provided for @yourSeat.
  ///
  /// In en, this message translates to:
  /// **'Your Seat'**
  String get yourSeat;

  /// No description provided for @ticketId.
  ///
  /// In en, this message translates to:
  /// **'Ticket: {id}'**
  String ticketId(int id);

  /// No description provided for @navigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get navigate;

  /// No description provided for @floorLabel.
  ///
  /// In en, this message translates to:
  /// **'Floor {level}'**
  String floorLabel(int level);

  /// No description provided for @queueTime.
  ///
  /// In en, this message translates to:
  /// **'{min} min queue'**
  String queueTime(int min);

  /// No description provided for @walkTime.
  ///
  /// In en, this message translates to:
  /// **'{min} min'**
  String walkTime(int min);

  /// No description provided for @removeSaved.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeSaved;

  /// No description provided for @savePlace.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get savePlace;

  /// No description provided for @ticketNotFound.
  ///
  /// In en, this message translates to:
  /// **'Ticket not found'**
  String get ticketNotFound;

  /// No description provided for @seatDescription.
  ///
  /// In en, this message translates to:
  /// **'Your reserved seat'**
  String get seatDescription;

  /// No description provided for @foodDescription.
  ///
  /// In en, this message translates to:
  /// **'Food and snacks'**
  String get foodDescription;

  /// No description provided for @barDescription.
  ///
  /// In en, this message translates to:
  /// **'Drinks available'**
  String get barDescription;

  /// No description provided for @restroomDescription.
  ///
  /// In en, this message translates to:
  /// **'Public restrooms'**
  String get restroomDescription;

  /// No description provided for @exitDescription.
  ///
  /// In en, this message translates to:
  /// **'Emergency exit'**
  String get exitDescription;

  /// No description provided for @firstAidDescription.
  ///
  /// In en, this message translates to:
  /// **'Medical assistance'**
  String get firstAidDescription;

  /// No description provided for @infoDescription.
  ///
  /// In en, this message translates to:
  /// **'Information desk'**
  String get infoDescription;

  /// No description provided for @defaultPoiDescription.
  ///
  /// In en, this message translates to:
  /// **'Point of interest'**
  String get defaultPoiDescription;

  /// No description provided for @invalidQRFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid QR code format'**
  String get invalidQRFormat;

  /// No description provided for @invalidQRSignature.
  ///
  /// In en, this message translates to:
  /// **'Invalid or tampered QR code'**
  String get invalidQRSignature;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error. Check your internet.'**
  String get connectionError;
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
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
