// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'MyNiyah';

  @override
  String get navHome => 'Home';

  @override
  String get navReminders => 'Reminders';

  @override
  String get navSettings => 'Settings';

  @override
  String get back => 'Back';

  @override
  String get close => 'Close';

  @override
  String get cancel => 'Cancel';

  @override
  String get off => 'Off';

  @override
  String get homeHeadline => 'Renew your intention.';

  @override
  String get homeSubtitle =>
      'A quiet reminder, whenever you need one — so what you do stays for Allah.';

  @override
  String get homeNextPrayer => 'Next prayer';

  @override
  String homeNextPrayerValue(String prayer, String time) {
    return '$prayer · $time';
  }

  @override
  String get homeQuickAccess => 'Quick access';

  @override
  String get homeRemindersTitle => 'My reminders';

  @override
  String get homeRemindersSubtitle => 'Choose when Niyah reminds you';

  @override
  String get homeSettingsTitle => 'Settings';

  @override
  String get homeSettingsSubtitle => 'Language, prayer times, quiet hours';

  @override
  String get remindersTitle => 'My reminders';

  @override
  String get remindersSubtitle => 'Small nudges to keep your niyyah sincere.';

  @override
  String get remindersAdd => 'Add';

  @override
  String get sectionMine => 'Written by me';

  @override
  String get sectionPrayer => 'Prayer';

  @override
  String get sectionFromNiyah => 'From Niyah';

  @override
  String remindersShowMore(int count) {
    return 'Show $count more';
  }

  @override
  String get remindersShowLess => 'Show less';

  @override
  String get remindersFromNiyahNote =>
      'Only reminders you added appear here. Find more with Add.';

  @override
  String get remindersEmptyMine => 'You haven\'t written a reminder yet.';

  @override
  String get remindersEmptyMineAction => 'Write your own';

  @override
  String get notificationsOff => 'Notifications are off';

  @override
  String get openSettings => 'Open settings';

  @override
  String scheduleTimeDays(String time, String days) {
    return '$time · $days';
  }

  @override
  String get scheduleEveryDay => 'Every day';

  @override
  String get scheduleNoDays => 'No days';

  @override
  String get scheduleWeekdays => 'Mon–Fri';

  @override
  String get scheduleWeekends => 'Weekends';

  @override
  String scheduleAtWakeUp(String time) {
    return 'At your wake-up time · $time';
  }

  @override
  String scheduleAtBedtime(String time) {
    return 'At your bedtime · $time';
  }

  @override
  String scheduleWeekendsAt(String time) {
    return 'weekends $time';
  }

  @override
  String offsetBeforeAdhan(int minutes) {
    return '$minutes min before adhan';
  }

  @override
  String get offsetAtAdhan => 'At adhan';

  @override
  String offsetAfterAdhan(int minutes) {
    return '$minutes min after adhan';
  }

  @override
  String schedulePrayers(String timing, String prayers) {
    return '$timing · $prayers';
  }

  @override
  String get everyPrayer => 'every prayer';

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
  String get addTitle => 'Add a reminder';

  @override
  String get backToReminders => 'Back to My reminders';

  @override
  String get addOwnWordsTitle => 'In your own words';

  @override
  String get addOwnWordsHint => 'Write what you want to be reminded of…';

  @override
  String get addOwnWordsLabel => 'Write your own reminder';

  @override
  String get addOwnWordsNote => 'You choose the words, the time and the days.';

  @override
  String get addOr => 'or';

  @override
  String get addReadyMadeTitle => 'Pick a ready-made moment';

  @override
  String get addReadyMadeNote =>
      'Tap one to choose its time before you add it.';

  @override
  String get addFilterLabel => 'Filter moments';

  @override
  String get filterAll => 'All';

  @override
  String get filterPrayer => 'Prayer';

  @override
  String get filterDaily => 'Daily';

  @override
  String get filterDhikr => 'Dhikr';

  @override
  String get filterWeekly => 'Weekly';

  @override
  String get groupPrayer => 'Around prayer';

  @override
  String get groupDaily => 'Your day';

  @override
  String get groupDhikr => 'Dhikr';

  @override
  String get groupWeekly => 'Weekly';

  @override
  String addChangeItem(String title) {
    return 'Change $title';
  }

  @override
  String addSetUpItem(String title) {
    return 'Set up and add $title';
  }

  @override
  String get fieldTime => 'Time';

  @override
  String get fieldDays => 'Days';

  @override
  String get hourLater => 'Hour later';

  @override
  String get hourEarlier => 'Hour earlier';

  @override
  String get minutesLater => 'Minutes later';

  @override
  String get minutesEarlier => 'Minutes earlier';

  @override
  String get anchorWakeLabel => 'Your wake-up time';

  @override
  String get anchorSleepLabel => 'Your bedtime';

  @override
  String get anchorWakeNote =>
      'Every reminder set to “after waking up” follows this time.';

  @override
  String get anchorSleepNote =>
      'Every reminder set to “before sleeping” follows this time.';

  @override
  String get differentOnWeekends => 'Different time on weekends';

  @override
  String get weekendDays => 'Sat & Sun';

  @override
  String get weekendEarlier => 'Weekend time earlier';

  @override
  String get weekendLater => 'Weekend time later';

  @override
  String get whichPrayers => 'Which prayers?';

  @override
  String get fieldWhen => 'When';

  @override
  String get earlier => 'Earlier';

  @override
  String get later => 'Later';

  @override
  String get pickOnePrayer => 'Pick at least one prayer';

  @override
  String get pickOneDay => 'Pick at least one day';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get addReminderCta => 'Add reminder';

  @override
  String get removeFromMine => 'Remove from my reminders';

  @override
  String get editorNewTitle => 'Write your own';

  @override
  String get editorEditTitle => 'Edit reminder';

  @override
  String get editorPreviewLabel => 'How it will arrive';

  @override
  String get editorTitleLabel => 'Title';

  @override
  String get editorTitleHint => 'e.g. Why am I doing this?';

  @override
  String get editorMessageLabel => 'Message';

  @override
  String get editorMessageHint =>
      'A few words to bring your heart back to its intention.';

  @override
  String editorCharsLeft(int count) {
    return '$count left';
  }

  @override
  String get editorIdeasLabel => 'Need words? Start from one of these';

  @override
  String get idea1Title => 'Is this for Allah?';

  @override
  String get idea1Body => 'Check your heart before you begin.';

  @override
  String get idea2Title => 'Renew your intention';

  @override
  String get idea2Body => 'Let this be for the pleasure of Allah.';

  @override
  String get idea3Title => 'Begin with Bismillah';

  @override
  String get idea3Body => 'A clear intention makes every step count.';

  @override
  String get editorWhenTitle => 'When should it reach you?';

  @override
  String get editorTriggerLabel => 'Reminder trigger';

  @override
  String get editorAtATime => 'At a time';

  @override
  String get editorAroundPrayer => 'Around a prayer';

  @override
  String editorTimeButtonLabel(String time) {
    return 'Time, $time. Tap to change';
  }

  @override
  String get editorTiming => 'Timing';

  @override
  String get editorPrivacyNote =>
      'Your words stay on this phone. Quiet hours are respected.';

  @override
  String get editorSave => 'Save reminder';

  @override
  String get editorDelete => 'Delete reminder';

  @override
  String get editorPreviewTitleFallback => 'Your title';

  @override
  String get editorPreviewBodyFallback => 'Your message will appear here.';

  @override
  String editorPreviewBeforePrayer(String prayer) {
    return 'before $prayer';
  }

  @override
  String get editorTextRequired => 'Write a title or a message.';

  @override
  String get deleteTitle => 'Delete this reminder?';

  @override
  String deleteBody(String title) {
    return '“$title” will be removed and won’t reach you again. Only need a break? Turn it off instead — you can switch it back on anytime.';
  }

  @override
  String get deleteConfirm => 'Delete';

  @override
  String get deleteTurnOff => 'Turn it off instead';

  @override
  String get prayerTitle => 'Prayer reminders';

  @override
  String get prayerMessageLabel => 'The message';

  @override
  String get prayerDefaultTitle => 'Renew your intention';

  @override
  String prayerDefaultBodyBefore(String prayer) {
    return '$prayer is near. Prepare your heart, and pray it for Allah alone.';
  }

  @override
  String prayerDefaultBodyAtAdhan(String prayer) {
    return 'It\'s time for $prayer. Pray it for Allah alone.';
  }

  @override
  String get prayerDefaultBodyAfter =>
      'Take a moment after the prayer, and keep your heart with Allah.';

  @override
  String get prayerChangeWords => 'Change the words';

  @override
  String get prayerTimingLabel => 'Timing';

  @override
  String get prayerModeBefore => 'Before';

  @override
  String get prayerModeAdhan => 'At adhan';

  @override
  String get prayerModeAfter => 'After';

  @override
  String get prayerHowLongBefore => 'How long before';

  @override
  String get prayerLessTime => 'Less time';

  @override
  String get prayerMoreTime => 'More time';

  @override
  String prayerMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String prayerMinBefore(int minutes) {
    return '$minutes min before';
  }

  @override
  String get prayerAfterPrayer => 'After prayer';

  @override
  String get prayerToday => 'Today';

  @override
  String prayerRemindMeFor(String prayer) {
    return 'Remind me for $prayer';
  }

  @override
  String get prayerDuringQuiet => 'Also during quiet hours';

  @override
  String get prayerDuringQuietNote =>
      'Fajr can still reach you while other reminders stay silent.';

  @override
  String get prayerDuringQuietLabel => 'Prayer reminders during quiet hours';

  @override
  String get prayerCardBefore => 'Before each prayer';

  @override
  String get prayerCardAtAdhan => 'At each adhan';

  @override
  String get prayerCardAfter => 'After each prayer';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsComingSoon =>
      'Language, prayer times and quiet hours will be here soon.';

  @override
  String notifPrayerAtTime(String prayer) {
    return 'It\'s time for $prayer';
  }

  @override
  String notifPrayerBefore(String prayer, int minutes) {
    return '$prayer in $minutes minutes';
  }

  @override
  String get notifRefreshBody =>
      'Open MyNiyah to keep receiving your reminders.';

  @override
  String get notifPrivateBody => 'Remember your intention';

  @override
  String get channelPrayer => 'Prayer';

  @override
  String get channelNiyyah => 'Intention';

  @override
  String get channelQuran => 'Qur\'an';

  @override
  String get channelHadith => 'Hadith';

  @override
  String get channelDhikr => 'Dhikr';

  @override
  String get channelGoodDeeds => 'Good deeds';

  @override
  String get channelIslamicEvents => 'Islamic events';

  @override
  String get channelPersonal => 'Personal';
}
