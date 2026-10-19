// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appName => 'MyNiyah';

  @override
  String get navHome => 'Home';

  @override
  String get navReminders => 'Promemoria';

  @override
  String get navSettings => 'Impostazioni';

  @override
  String get back => 'Indietro';

  @override
  String get close => 'Chiudi';

  @override
  String get cancel => 'Annulla';

  @override
  String get off => 'Disattivato';

  @override
  String get homeHeadline => 'Rinnova la tua intenzione.';

  @override
  String get homeSubtitle =>
      'Un promemoria discreto, quando ti serve — perché ciò che fai resti per Allah.';

  @override
  String get homeNextPrayer => 'Prossima preghiera';

  @override
  String homeNextPrayerValue(String prayer, String time) {
    return '$prayer · $time';
  }

  @override
  String get homeQuickAccess => 'Accesso rapido';

  @override
  String get homeRemindersTitle => 'I miei promemoria';

  @override
  String get homeRemindersSubtitle => 'Scegli quando Niyah ti ricorda';

  @override
  String get homeSettingsTitle => 'Impostazioni';

  @override
  String get homeSettingsSubtitle =>
      'Lingua, orari di preghiera, non disturbare';

  @override
  String get remindersTitle => 'I miei promemoria';

  @override
  String get remindersSubtitle =>
      'Piccoli richiami per mantenere sincera la tua niyyah.';

  @override
  String get remindersAdd => 'Aggiungi';

  @override
  String get sectionMine => 'Scritti da me';

  @override
  String get sectionPrayer => 'Preghiera';

  @override
  String get sectionFromNiyah => 'Da Niyah';

  @override
  String remindersShowMore(int count) {
    return 'Mostra altri $count';
  }

  @override
  String get remindersShowLess => 'Mostra meno';

  @override
  String get remindersFromNiyahNote =>
      'Qui compaiono solo i promemoria che hai aggiunto. Trovane altri con Aggiungi.';

  @override
  String get remindersEmptyMine => 'Non hai ancora scritto nessun promemoria.';

  @override
  String get remindersEmptyMineAction => 'Scrivine uno tuo';

  @override
  String get notificationsOff => 'Le notifiche sono disattivate';

  @override
  String get openSettings => 'Apri impostazioni';

  @override
  String scheduleTimeDays(String time, String days) {
    return '$time · $days';
  }

  @override
  String get scheduleEveryDay => 'Ogni giorno';

  @override
  String get scheduleNoDays => 'Nessun giorno';

  @override
  String get scheduleWeekdays => 'Lun–Ven';

  @override
  String get scheduleWeekends => 'Weekend';

  @override
  String scheduleAtWakeUp(String time) {
    return 'Al tuo risveglio · $time';
  }

  @override
  String scheduleAtBedtime(String time) {
    return 'Prima di dormire · $time';
  }

  @override
  String scheduleWeekendsAt(String time) {
    return 'weekend $time';
  }

  @override
  String offsetBeforeAdhan(int minutes) {
    return '$minutes min prima dell\'adhan';
  }

  @override
  String get offsetAtAdhan => 'All\'adhan';

  @override
  String offsetAfterAdhan(int minutes) {
    return '$minutes min dopo l\'adhan';
  }

  @override
  String schedulePrayers(String timing, String prayers) {
    return '$timing · $prayers';
  }

  @override
  String get everyPrayer => 'ogni preghiera';

  @override
  String get prayerFajr => 'Fajr';

  @override
  String get prayerDhuhr => 'Dhuhr';

  @override
  String get prayerAsr => 'Asr';

  @override
  String get prayerMaghrib => 'Maghrib';

  @override
  String get prayerIsha => 'Isha';

  @override
  String get addTitle => 'Aggiungi un promemoria';

  @override
  String get backToReminders => 'Torna a I miei promemoria';

  @override
  String get addOwnWordsTitle => 'Con parole tue';

  @override
  String get addOwnWordsHint => 'Scrivi cosa vuoi ricordare…';

  @override
  String get addOwnWordsLabel => 'Scrivi un tuo promemoria';

  @override
  String get addOwnWordsNote => 'Scegli tu le parole, l\'orario e i giorni.';

  @override
  String get addOr => 'oppure';

  @override
  String get addReadyMadeTitle => 'Scegli un momento già pronto';

  @override
  String get addReadyMadeNote =>
      'Toccane uno per sceglierne l\'orario prima di aggiungerlo.';

  @override
  String get addFilterLabel => 'Filtra i momenti';

  @override
  String get filterAll => 'Tutti';

  @override
  String get filterPrayer => 'Preghiera';

  @override
  String get filterDaily => 'Giornata';

  @override
  String get filterDhikr => 'Dhikr';

  @override
  String get filterWeekly => 'Settimana';

  @override
  String get groupPrayer => 'Intorno alla preghiera';

  @override
  String get groupDaily => 'La tua giornata';

  @override
  String get groupDhikr => 'Dhikr';

  @override
  String get groupWeekly => 'Ogni settimana';

  @override
  String addChangeItem(String title) {
    return 'Modifica $title';
  }

  @override
  String addSetUpItem(String title) {
    return 'Imposta e aggiungi $title';
  }

  @override
  String get fieldTime => 'Orario';

  @override
  String get fieldDays => 'Giorni';

  @override
  String get hourLater => 'Un\'ora dopo';

  @override
  String get hourEarlier => 'Un\'ora prima';

  @override
  String get minutesLater => 'Minuti dopo';

  @override
  String get minutesEarlier => 'Minuti prima';

  @override
  String get anchorWakeLabel => 'Il tuo orario di risveglio';

  @override
  String get anchorSleepLabel => 'Il tuo orario per dormire';

  @override
  String get anchorWakeNote =>
      'Ogni promemoria impostato «dopo il risveglio» segue questo orario.';

  @override
  String get anchorSleepNote =>
      'Ogni promemoria impostato «prima di dormire» segue questo orario.';

  @override
  String get differentOnWeekends => 'Orario diverso nel weekend';

  @override
  String get weekendDays => 'Sab e Dom';

  @override
  String get weekendEarlier => 'Orario del weekend prima';

  @override
  String get weekendLater => 'Orario del weekend dopo';

  @override
  String get whichPrayers => 'Quali preghiere?';

  @override
  String get fieldWhen => 'Quando';

  @override
  String get earlier => 'Prima';

  @override
  String get later => 'Dopo';

  @override
  String get pickOnePrayer => 'Scegli almeno una preghiera';

  @override
  String get pickOneDay => 'Scegli almeno un giorno';

  @override
  String get saveChanges => 'Salva modifiche';

  @override
  String get addReminderCta => 'Aggiungi promemoria';

  @override
  String get removeFromMine => 'Rimuovi dai miei promemoria';

  @override
  String get editorNewTitle => 'Scrivi il tuo';

  @override
  String get editorEditTitle => 'Modifica promemoria';

  @override
  String get editorPreviewLabel => 'Come arriverà';

  @override
  String get editorTitleLabel => 'Titolo';

  @override
  String get editorTitleHint => 'es. Perché lo sto facendo?';

  @override
  String get editorMessageLabel => 'Messaggio';

  @override
  String get editorMessageHint =>
      'Poche parole per riportare il cuore alla sua intenzione.';

  @override
  String editorCharsLeft(int count) {
    return '$count rimasti';
  }

  @override
  String get editorIdeasLabel => 'Ti servono parole? Parti da una di queste';

  @override
  String get idea1Title => 'È per Allah?';

  @override
  String get idea1Body => 'Controlla il tuo cuore prima di iniziare.';

  @override
  String get idea2Title => 'Rinnova la tua intenzione';

  @override
  String get idea2Body => 'Che sia per il compiacimento di Allah.';

  @override
  String get idea3Title => 'Inizia con Bismillah';

  @override
  String get idea3Body => 'Un\'intenzione chiara dà valore a ogni passo.';

  @override
  String get editorWhenTitle => 'Quando deve raggiungerti?';

  @override
  String get editorTriggerLabel => 'Quando arriva il promemoria';

  @override
  String get editorAtATime => 'A un orario';

  @override
  String get editorAroundPrayer => 'Intorno a una preghiera';

  @override
  String editorTimeButtonLabel(String time) {
    return 'Orario, $time. Tocca per cambiarlo';
  }

  @override
  String get editorTiming => 'Tempistica';

  @override
  String get editorPrivacyNote =>
      'Le tue parole restano su questo telefono. Il «non disturbare» viene rispettato.';

  @override
  String get editorSave => 'Salva promemoria';

  @override
  String get editorDelete => 'Elimina promemoria';

  @override
  String get editorPreviewTitleFallback => 'Il tuo titolo';

  @override
  String get editorPreviewBodyFallback => 'Il tuo messaggio apparirà qui.';

  @override
  String editorPreviewBeforePrayer(String prayer) {
    return 'prima di $prayer';
  }

  @override
  String get editorTextRequired => 'Scrivi un titolo o un messaggio.';

  @override
  String get deleteTitle => 'Eliminare questo promemoria?';

  @override
  String deleteBody(String title) {
    return '«$title» verrà eliminato e non ti raggiungerà più. Ti serve solo una pausa? Disattivalo invece — puoi riattivarlo quando vuoi.';
  }

  @override
  String get deleteConfirm => 'Elimina';

  @override
  String get deleteTurnOff => 'Disattivalo invece';

  @override
  String get prayerTitle => 'Promemoria di preghiera';

  @override
  String get prayerMessageLabel => 'Il messaggio';

  @override
  String get prayerDefaultTitle => 'Rinnova la tua intenzione';

  @override
  String prayerDefaultBodyBefore(String prayer) {
    return '$prayer si avvicina. Prepara il cuore e pregala solo per Allah.';
  }

  @override
  String prayerDefaultBodyAtAdhan(String prayer) {
    return 'È l\'ora di $prayer. Pregala solo per Allah.';
  }

  @override
  String get prayerDefaultBodyAfter =>
      'Prenditi un momento dopo la preghiera e tieni il cuore con Allah.';

  @override
  String get prayerChangeWords => 'Cambia le parole';

  @override
  String get prayerTimingLabel => 'Tempistica';

  @override
  String get prayerModeBefore => 'Prima';

  @override
  String get prayerModeAdhan => 'All\'adhan';

  @override
  String get prayerModeAfter => 'Dopo';

  @override
  String get prayerHowLongBefore => 'Quanto prima';

  @override
  String get prayerLessTime => 'Meno tempo';

  @override
  String get prayerMoreTime => 'Più tempo';

  @override
  String prayerMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String prayerMinBefore(int minutes) {
    return '$minutes min prima';
  }

  @override
  String get prayerAfterPrayer => 'Dopo la preghiera';

  @override
  String get prayerToday => 'Oggi';

  @override
  String prayerRemindMeFor(String prayer) {
    return 'Ricordami per $prayer';
  }

  @override
  String get prayerDuringQuiet => 'Anche durante il non disturbare';

  @override
  String get prayerDuringQuietNote =>
      'Il Fajr può raggiungerti anche quando gli altri promemoria tacciono.';

  @override
  String get prayerDuringQuietLabel =>
      'Promemoria di preghiera durante il non disturbare';

  @override
  String get prayerCardBefore => 'Prima di ogni preghiera';

  @override
  String get prayerCardAtAdhan => 'A ogni adhan';

  @override
  String get prayerCardAfter => 'Dopo ogni preghiera';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsComingSoon =>
      'Lingua, orari di preghiera e non disturbare arriveranno presto.';

  @override
  String notifPrayerAtTime(String prayer) {
    return 'È l\'ora di $prayer';
  }

  @override
  String notifPrayerBefore(String prayer, int minutes) {
    return '$prayer tra $minutes minuti';
  }

  @override
  String get notifRefreshBody =>
      'Apri MyNiyah per continuare a ricevere i promemoria.';

  @override
  String get notifPrivateBody => 'Ricorda la tua intenzione';

  @override
  String get channelPrayer => 'Preghiera';

  @override
  String get channelNiyyah => 'Intenzione';

  @override
  String get channelQuran => 'Corano';

  @override
  String get channelHadith => 'Hadith';

  @override
  String get channelDhikr => 'Dhikr';

  @override
  String get channelGoodDeeds => 'Buone azioni';

  @override
  String get channelIslamicEvents => 'Eventi islamici';

  @override
  String get channelPersonal => 'Personali';
}
