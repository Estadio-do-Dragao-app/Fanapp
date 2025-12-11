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

  @override
  String get turnLeft => 'Turn left';

  @override
  String get turnRight => 'Turn right';

  @override
  String get continueStraight => 'Continue straight';

  @override
  String get arriveAtDestination => 'Arrive at destination';

  @override
  String get arrival => 'arrival';

  @override
  String get time => 'hrs';

  @override
  String get distance => 'm';

  @override
  String get destination => 'destination';

  @override
  String get endRoute => 'End Route';

  @override
  String get firstAid => 'First Aid';

  @override
  String get information => 'Information';

  @override
  String get merchandising => 'Merchandising';
}
