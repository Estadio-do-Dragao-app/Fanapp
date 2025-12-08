// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get search => 'Search...';

  @override
  String get whereToQuestion => 'Where to?';

  @override
  String get seat => 'Seat';

  @override
  String get wc => 'WC';

  @override
  String get food => 'Food';

  @override
  String get exit => 'Exit';

  @override
  String selected(String item) {
    return 'Selected: $item';
  }

  @override
  String get tapToSelect => 'Tap to select';

  @override
  String get chooseLocation => 'Choose a location';

  @override
  String get chooseLocationButton => 'Choose location';

  @override
  String get faster => 'Faster';

  @override
  String minutes(int count) {
    return '$count min';
  }

  @override
  String get evacuation => 'EVACUATION';

  @override
  String get map => 'MAP';
}
