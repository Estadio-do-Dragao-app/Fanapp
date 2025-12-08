// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get search => 'Pesquisar...';

  @override
  String get whereToQuestion => 'Para onde?';

  @override
  String get seat => 'Lugar';

  @override
  String get wc => 'WC';

  @override
  String get food => 'Comida';

  @override
  String get exit => 'Saída';

  @override
  String selected(String item) {
    return 'Selecionado: $item';
  }

  @override
  String get tapToSelect => 'Toque para selecionar';

  @override
  String get chooseLocation => 'Escolha uma localização';

  @override
  String get chooseLocationButton => 'Escolher localização';

  @override
  String get faster => 'Mais rápido';

  @override
  String minutes(int count) {
    return '$count min';
  }
}
