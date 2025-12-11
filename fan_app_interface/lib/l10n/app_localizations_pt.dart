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

  @override
  String get evacuation => 'EVACUAÇÃO';

  @override
  String get map => 'MAPA';

  @override
  String get turnLeft => 'Vire à esquerda';

  @override
  String get turnRight => 'Vire à direita';

  @override
  String get continueStraight => 'Continue em frente';

  @override
  String get arriveAtDestination => 'Chegada ao destino';

  @override
  String get arrival => 'chegada';

  @override
  String get time => 'hrs';

  @override
  String get distance => 'm';

  @override
  String get destination => 'destino';

  @override
  String get endRoute => 'Terminar Rota';

  @override
  String get addTicket => 'Adicionar Bilhete';

  @override
  String get scanTicketQR => 'Digitalizar QR do Bilhete';

  @override
  String get ticketInfo => 'Informação do Bilhete';

  @override
  String get sector => 'Setor';

  @override
  String get row => 'Fila';

  @override
  String get gate => 'Portão';

  @override
  String get ticketType => 'Tipo de Bilhete';

  @override
  String get deleteTicket => 'Apagar Bilhete';

  @override
  String get deleteTicketConfirm => 'Tem a certeza que quer apagar este bilhete?';

  @override
  String get noTicketScanned => 'Nenhum bilhete digitalizado';

  @override
  String get noTicketScannedMessage => 'Por favor digitalize o código QR do seu bilhete para navegar até ao seu lugar.';

  @override
  String get scanNow => 'Digitalizar Agora';

  @override
  String get cancel => 'Cancelar';

  @override
  String get firstAid => 'Primeiros Socorros';

  @override
  String get information => 'Informação';

  @override
  String get merchandising => 'Loja';
}
