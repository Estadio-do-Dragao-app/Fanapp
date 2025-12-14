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
  String get addTicket => 'Add Ticket';

  @override
  String get scanTicketQR => 'Scan Ticket QR Code';

  @override
  String get ticketInfo => 'Ticket Information';

  @override
  String get sector => 'Sector';

  @override
  String get row => 'Row';

  @override
  String get gate => 'Gate';

  @override
  String get ticketType => 'Ticket Type';

  @override
  String get deleteTicket => 'Delete Ticket';

  @override
  String get deleteTicketConfirm => 'Are you sure you want to delete this ticket?';

  @override
  String get noTicketScanned => 'No ticket scanned';

  @override
  String get noTicketScannedMessage => 'Please scan your ticket QR code to navigate to your seat.';

  @override
  String get scanNow => 'Scan Now';

  @override
  String get cancel => 'Cancel';

  @override
  String get firstAid => 'First Aid';

  @override
  String get information => 'Information';

  @override
  String get merchandising => 'Merchandising';

  @override
  String get filter => 'Filter';

  @override
  String get floor => 'Floor';

  @override
  String get heatmap => 'Heat map';

  @override
  String get accessibility => 'Accessibility';

  @override
  String get connectionFailed => 'Connection failed';

  @override
  String get newDestinationFound => 'NEW DESTINATION FOUND';

  @override
  String lessQueue(String place) {
    return '$place has less queue';
  }

  @override
  String get change => 'Change';

  @override
  String get no => 'No';

  @override
  String durationMin(String time) {
    return '$time';
  }

  @override
  String distanceM(int dist) {
    return '$dist m';
  }
}
