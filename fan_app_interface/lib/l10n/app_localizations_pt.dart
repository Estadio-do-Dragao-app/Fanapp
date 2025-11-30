// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get exit => 'Saída';

  @override
  String get food => 'Comida';

  @override
  String get search => 'Pesquisar...';

  @override
  String get seat => 'Lugar';

  @override
  String selected(String item) {
    return 'Selecionado: $item';
  }

  @override
  String get tapToSelect => 'Toque para selecionar';

  @override
  String get wc => 'WC';

  @override
  String get whereToQuestion => 'Para onde?';
}
