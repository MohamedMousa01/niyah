import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('it'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'MyNiyah'**
  String get appName;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get navReminders;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @homeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Renew your intention.'**
  String get homeHeadline;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A quiet reminder, whenever you need one — so what you do stays for Allah.'**
  String get homeSubtitle;

  /// No description provided for @homeNextPrayer.
  ///
  /// In en, this message translates to:
  /// **'Next prayer'**
  String get homeNextPrayer;

  /// No description provided for @homeNextPrayerValue.
  ///
  /// In en, this message translates to:
  /// **'{prayer} · {time}'**
  String homeNextPrayerValue(String prayer, String time);

  /// No description provided for @homeQuickAccess.
  ///
  /// In en, this message translates to:
  /// **'Quick access'**
  String get homeQuickAccess;

  /// No description provided for @homeRemindersTitle.
  ///
  /// In en, this message translates to:
  /// **'My reminders'**
  String get homeRemindersTitle;

  /// No description provided for @homeRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose when Niyah reminds you'**
  String get homeRemindersSubtitle;

  /// No description provided for @homeSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeSettingsTitle;

  /// No description provided for @homeSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Language, prayer times, quiet hours'**
  String get homeSettingsSubtitle;

  /// No description provided for @remindersTitle.
  ///
  /// In en, this message translates to:
  /// **'My reminders'**
  String get remindersTitle;

  /// No description provided for @remindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Small nudges to keep your niyyah sincere.'**
  String get remindersSubtitle;

  /// No description provided for @remindersAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get remindersAdd;

  /// No description provided for @sectionMine.
  ///
  /// In en, this message translates to:
  /// **'Written by me'**
  String get sectionMine;

  /// No description provided for @sectionPrayer.
  ///
  /// In en, this message translates to:
  /// **'Prayer'**
  String get sectionPrayer;

  /// No description provided for @sectionFromNiyah.
  ///
  /// In en, this message translates to:
  /// **'From Niyah'**
  String get sectionFromNiyah;

  /// No description provided for @remindersShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show {count} more'**
  String remindersShowMore(int count);

  /// No description provided for @remindersShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get remindersShowLess;

  /// No description provided for @remindersFromNiyahNote.
  ///
  /// In en, this message translates to:
  /// **'Only reminders you added appear here. Find more with Add.'**
  String get remindersFromNiyahNote;

  /// No description provided for @remindersEmptyMine.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t written a reminder yet.'**
  String get remindersEmptyMine;

  /// No description provided for @remindersEmptyMineAction.
  ///
  /// In en, this message translates to:
  /// **'Write your own'**
  String get remindersEmptyMineAction;

  /// No description provided for @notificationsOff.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off'**
  String get notificationsOff;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @scheduleTimeDays.
  ///
  /// In en, this message translates to:
  /// **'{time} · {days}'**
  String scheduleTimeDays(String time, String days);

  /// No description provided for @scheduleEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get scheduleEveryDay;

  /// No description provided for @scheduleNoDays.
  ///
  /// In en, this message translates to:
  /// **'No days'**
  String get scheduleNoDays;

  /// No description provided for @scheduleWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Mon–Fri'**
  String get scheduleWeekdays;

  /// No description provided for @scheduleWeekends.
  ///
  /// In en, this message translates to:
  /// **'Weekends'**
  String get scheduleWeekends;

  /// No description provided for @scheduleAtWakeUp.
  ///
  /// In en, this message translates to:
  /// **'At your wake-up time · {time}'**
  String scheduleAtWakeUp(String time);

  /// No description provided for @scheduleAtBedtime.
  ///
  /// In en, this message translates to:
  /// **'At your bedtime · {time}'**
  String scheduleAtBedtime(String time);

  /// No description provided for @scheduleWeekendsAt.
  ///
  /// In en, this message translates to:
  /// **'weekends {time}'**
  String scheduleWeekendsAt(String time);

  /// No description provided for @offsetBeforeAdhan.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min before adhan'**
  String offsetBeforeAdhan(int minutes);

  /// No description provided for @offsetAtAdhan.
  ///
  /// In en, this message translates to:
  /// **'At adhan'**
  String get offsetAtAdhan;

  /// No description provided for @offsetAfterAdhan.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min after adhan'**
  String offsetAfterAdhan(int minutes);

  /// No description provided for @schedulePrayers.
  ///
  /// In en, this message translates to:
  /// **'{timing} · {prayers}'**
  String schedulePrayers(String timing, String prayers);

  /// No description provided for @everyPrayer.
  ///
  /// In en, this message translates to:
  /// **'every prayer'**
  String get everyPrayer;

  /// No description provided for @prayerFajr.
  ///
  /// In en, this message translates to:
  /// **'Fajr'**
  String get prayerFajr;

  /// No description provided for @prayerDhuhr.
  ///
  /// In en, this message translates to:
  /// **'Dhuhr'**
  String get prayerDhuhr;

  /// No description provided for @prayerAsr.
  ///
  /// In en, this message translates to:
  /// **'Asr'**
  String get prayerAsr;

  /// No description provided for @prayerMaghrib.
  ///
  /// In en, this message translates to:
  /// **'Maghrib'**
  String get prayerMaghrib;

  /// No description provided for @prayerIsha.
  ///
  /// In en, this message translates to:
  /// **'Isha'**
  String get prayerIsha;

  /// No description provided for @addTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a reminder'**
  String get addTitle;

  /// No description provided for @backToReminders.
  ///
  /// In en, this message translates to:
  /// **'Back to My reminders'**
  String get backToReminders;

  /// No description provided for @addOwnWordsTitle.
  ///
  /// In en, this message translates to:
  /// **'In your own words'**
  String get addOwnWordsTitle;

  /// No description provided for @addOwnWordsHint.
  ///
  /// In en, this message translates to:
  /// **'Write what you want to be reminded of…'**
  String get addOwnWordsHint;

  /// No description provided for @addOwnWordsLabel.
  ///
  /// In en, this message translates to:
  /// **'Write your own reminder'**
  String get addOwnWordsLabel;

  /// No description provided for @addOwnWordsNote.
  ///
  /// In en, this message translates to:
  /// **'You choose the words, the time and the days.'**
  String get addOwnWordsNote;

  /// No description provided for @addOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get addOr;

  /// No description provided for @addReadyMadeTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a ready-made moment'**
  String get addReadyMadeTitle;

  /// No description provided for @addReadyMadeNote.
  ///
  /// In en, this message translates to:
  /// **'Tap one to choose its time before you add it.'**
  String get addReadyMadeNote;

  /// No description provided for @addFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter moments'**
  String get addFilterLabel;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterPrayer.
  ///
  /// In en, this message translates to:
  /// **'Prayer'**
  String get filterPrayer;

  /// No description provided for @filterDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get filterDaily;

  /// No description provided for @filterDhikr.
  ///
  /// In en, this message translates to:
  /// **'Dhikr'**
  String get filterDhikr;

  /// No description provided for @filterWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get filterWeekly;

  /// No description provided for @groupPrayer.
  ///
  /// In en, this message translates to:
  /// **'Around prayer'**
  String get groupPrayer;

  /// No description provided for @groupDaily.
  ///
  /// In en, this message translates to:
  /// **'Your day'**
  String get groupDaily;

  /// No description provided for @groupDhikr.
  ///
  /// In en, this message translates to:
  /// **'Dhikr'**
  String get groupDhikr;

  /// No description provided for @groupWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get groupWeekly;

  /// No description provided for @addChangeItem.
  ///
  /// In en, this message translates to:
  /// **'Change {title}'**
  String addChangeItem(String title);

  /// No description provided for @addSetUpItem.
  ///
  /// In en, this message translates to:
  /// **'Set up and add {title}'**
  String addSetUpItem(String title);

  /// No description provided for @fieldTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get fieldTime;

  /// No description provided for @fieldDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get fieldDays;

  /// No description provided for @hourLater.
  ///
  /// In en, this message translates to:
  /// **'Hour later'**
  String get hourLater;

  /// No description provided for @hourEarlier.
  ///
  /// In en, this message translates to:
  /// **'Hour earlier'**
  String get hourEarlier;

  /// No description provided for @minutesLater.
  ///
  /// In en, this message translates to:
  /// **'Minutes later'**
  String get minutesLater;

  /// No description provided for @minutesEarlier.
  ///
  /// In en, this message translates to:
  /// **'Minutes earlier'**
  String get minutesEarlier;

  /// No description provided for @anchorWakeLabel.
  ///
  /// In en, this message translates to:
  /// **'Your wake-up time'**
  String get anchorWakeLabel;

  /// No description provided for @anchorSleepLabel.
  ///
  /// In en, this message translates to:
  /// **'Your bedtime'**
  String get anchorSleepLabel;

  /// No description provided for @anchorWakeNote.
  ///
  /// In en, this message translates to:
  /// **'Every reminder set to “after waking up” follows this time.'**
  String get anchorWakeNote;

  /// No description provided for @anchorSleepNote.
  ///
  /// In en, this message translates to:
  /// **'Every reminder set to “before sleeping” follows this time.'**
  String get anchorSleepNote;

  /// No description provided for @differentOnWeekends.
  ///
  /// In en, this message translates to:
  /// **'Different time on weekends'**
  String get differentOnWeekends;

  /// No description provided for @weekendDays.
  ///
  /// In en, this message translates to:
  /// **'Sat & Sun'**
  String get weekendDays;

  /// No description provided for @weekendEarlier.
  ///
  /// In en, this message translates to:
  /// **'Weekend time earlier'**
  String get weekendEarlier;

  /// No description provided for @weekendLater.
  ///
  /// In en, this message translates to:
  /// **'Weekend time later'**
  String get weekendLater;

  /// No description provided for @whichPrayers.
  ///
  /// In en, this message translates to:
  /// **'Which prayers?'**
  String get whichPrayers;

  /// No description provided for @fieldWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get fieldWhen;

  /// No description provided for @earlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get earlier;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @pickOnePrayer.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one prayer'**
  String get pickOnePrayer;

  /// No description provided for @pickOneDay.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one day'**
  String get pickOneDay;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @addReminderCta.
  ///
  /// In en, this message translates to:
  /// **'Add reminder'**
  String get addReminderCta;

  /// No description provided for @removeFromMine.
  ///
  /// In en, this message translates to:
  /// **'Remove from my reminders'**
  String get removeFromMine;

  /// No description provided for @editorNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Write your own'**
  String get editorNewTitle;

  /// No description provided for @editorEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit reminder'**
  String get editorEditTitle;

  /// No description provided for @editorPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'How it will arrive'**
  String get editorPreviewLabel;

  /// No description provided for @editorTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get editorTitleLabel;

  /// No description provided for @editorTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Why am I doing this?'**
  String get editorTitleHint;

  /// No description provided for @editorMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get editorMessageLabel;

  /// No description provided for @editorMessageHint.
  ///
  /// In en, this message translates to:
  /// **'A few words to bring your heart back to its intention.'**
  String get editorMessageHint;

  /// No description provided for @editorCharsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} left'**
  String editorCharsLeft(int count);

  /// No description provided for @editorIdeasLabel.
  ///
  /// In en, this message translates to:
  /// **'Need words? Start from one of these'**
  String get editorIdeasLabel;

  /// No description provided for @idea1Title.
  ///
  /// In en, this message translates to:
  /// **'Is this for Allah?'**
  String get idea1Title;

  /// No description provided for @idea1Body.
  ///
  /// In en, this message translates to:
  /// **'Check your heart before you begin.'**
  String get idea1Body;

  /// No description provided for @idea2Title.
  ///
  /// In en, this message translates to:
  /// **'Renew your intention'**
  String get idea2Title;

  /// No description provided for @idea2Body.
  ///
  /// In en, this message translates to:
  /// **'Let this be for the pleasure of Allah.'**
  String get idea2Body;

  /// No description provided for @idea3Title.
  ///
  /// In en, this message translates to:
  /// **'Begin with Bismillah'**
  String get idea3Title;

  /// No description provided for @idea3Body.
  ///
  /// In en, this message translates to:
  /// **'A clear intention makes every step count.'**
  String get idea3Body;

  /// No description provided for @editorWhenTitle.
  ///
  /// In en, this message translates to:
  /// **'When should it reach you?'**
  String get editorWhenTitle;

  /// No description provided for @editorTriggerLabel.
  ///
  /// In en, this message translates to:
  /// **'Reminder trigger'**
  String get editorTriggerLabel;

  /// No description provided for @editorAtATime.
  ///
  /// In en, this message translates to:
  /// **'At a time'**
  String get editorAtATime;

  /// No description provided for @editorAroundPrayer.
  ///
  /// In en, this message translates to:
  /// **'Around a prayer'**
  String get editorAroundPrayer;

  /// No description provided for @editorTimeButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Time, {time}. Tap to change'**
  String editorTimeButtonLabel(String time);

  /// No description provided for @editorTiming.
  ///
  /// In en, this message translates to:
  /// **'Timing'**
  String get editorTiming;

  /// No description provided for @editorPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Your words stay on this phone. Quiet hours are respected.'**
  String get editorPrivacyNote;

  /// No description provided for @editorSave.
  ///
  /// In en, this message translates to:
  /// **'Save reminder'**
  String get editorSave;

  /// No description provided for @editorDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete reminder'**
  String get editorDelete;

  /// No description provided for @editorPreviewTitleFallback.
  ///
  /// In en, this message translates to:
  /// **'Your title'**
  String get editorPreviewTitleFallback;

  /// No description provided for @editorPreviewBodyFallback.
  ///
  /// In en, this message translates to:
  /// **'Your message will appear here.'**
  String get editorPreviewBodyFallback;

  /// No description provided for @editorPreviewBeforePrayer.
  ///
  /// In en, this message translates to:
  /// **'before {prayer}'**
  String editorPreviewBeforePrayer(String prayer);

  /// No description provided for @editorTextRequired.
  ///
  /// In en, this message translates to:
  /// **'Write a title or a message.'**
  String get editorTextRequired;

  /// No description provided for @deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this reminder?'**
  String get deleteTitle;

  /// No description provided for @deleteBody.
  ///
  /// In en, this message translates to:
  /// **'“{title}” will be removed and won’t reach you again. Only need a break? Turn it off instead — you can switch it back on anytime.'**
  String deleteBody(String title);

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteConfirm;

  /// No description provided for @deleteTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn it off instead'**
  String get deleteTurnOff;

  /// No description provided for @prayerTitle.
  ///
  /// In en, this message translates to:
  /// **'Prayer reminders'**
  String get prayerTitle;

  /// No description provided for @prayerMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'The message'**
  String get prayerMessageLabel;

  /// No description provided for @prayerDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Renew your intention'**
  String get prayerDefaultTitle;

  /// No description provided for @prayerDefaultBodyBefore.
  ///
  /// In en, this message translates to:
  /// **'{prayer} is near. Prepare your heart, and pray it for Allah alone.'**
  String prayerDefaultBodyBefore(String prayer);

  /// No description provided for @prayerDefaultBodyAtAdhan.
  ///
  /// In en, this message translates to:
  /// **'It\'s time for {prayer}. Pray it for Allah alone.'**
  String prayerDefaultBodyAtAdhan(String prayer);

  /// No description provided for @prayerDefaultBodyAfter.
  ///
  /// In en, this message translates to:
  /// **'Take a moment after the prayer, and keep your heart with Allah.'**
  String get prayerDefaultBodyAfter;

  /// No description provided for @prayerChangeWords.
  ///
  /// In en, this message translates to:
  /// **'Change the words'**
  String get prayerChangeWords;

  /// No description provided for @prayerTimingLabel.
  ///
  /// In en, this message translates to:
  /// **'Timing'**
  String get prayerTimingLabel;

  /// No description provided for @prayerModeBefore.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get prayerModeBefore;

  /// No description provided for @prayerModeAdhan.
  ///
  /// In en, this message translates to:
  /// **'At adhan'**
  String get prayerModeAdhan;

  /// No description provided for @prayerModeAfter.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get prayerModeAfter;

  /// No description provided for @prayerHowLongBefore.
  ///
  /// In en, this message translates to:
  /// **'How long before'**
  String get prayerHowLongBefore;

  /// No description provided for @prayerLessTime.
  ///
  /// In en, this message translates to:
  /// **'Less time'**
  String get prayerLessTime;

  /// No description provided for @prayerMoreTime.
  ///
  /// In en, this message translates to:
  /// **'More time'**
  String get prayerMoreTime;

  /// No description provided for @prayerMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String prayerMinutes(int minutes);

  /// No description provided for @prayerMinBefore.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min before'**
  String prayerMinBefore(int minutes);

  /// No description provided for @prayerAfterPrayer.
  ///
  /// In en, this message translates to:
  /// **'After prayer'**
  String get prayerAfterPrayer;

  /// No description provided for @prayerToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get prayerToday;

  /// No description provided for @prayerRemindMeFor.
  ///
  /// In en, this message translates to:
  /// **'Remind me for {prayer}'**
  String prayerRemindMeFor(String prayer);

  /// No description provided for @prayerDuringQuiet.
  ///
  /// In en, this message translates to:
  /// **'Also during quiet hours'**
  String get prayerDuringQuiet;

  /// No description provided for @prayerDuringQuietNote.
  ///
  /// In en, this message translates to:
  /// **'Fajr can still reach you while other reminders stay silent.'**
  String get prayerDuringQuietNote;

  /// No description provided for @prayerDuringQuietLabel.
  ///
  /// In en, this message translates to:
  /// **'Prayer reminders during quiet hours'**
  String get prayerDuringQuietLabel;

  /// No description provided for @prayerCardBefore.
  ///
  /// In en, this message translates to:
  /// **'Before each prayer'**
  String get prayerCardBefore;

  /// No description provided for @prayerCardAtAdhan.
  ///
  /// In en, this message translates to:
  /// **'At each adhan'**
  String get prayerCardAtAdhan;

  /// No description provided for @prayerCardAfter.
  ///
  /// In en, this message translates to:
  /// **'After each prayer'**
  String get prayerCardAfter;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Language, prayer times and quiet hours will be here soon.'**
  String get settingsComingSoon;

  /// No description provided for @notifPrayerAtTime.
  ///
  /// In en, this message translates to:
  /// **'It\'s time for {prayer}'**
  String notifPrayerAtTime(String prayer);

  /// No description provided for @notifPrayerBefore.
  ///
  /// In en, this message translates to:
  /// **'{prayer} in {minutes} minutes'**
  String notifPrayerBefore(String prayer, int minutes);

  /// No description provided for @notifRefreshBody.
  ///
  /// In en, this message translates to:
  /// **'Open MyNiyah to keep receiving your reminders.'**
  String get notifRefreshBody;

  /// No description provided for @notifPrivateBody.
  ///
  /// In en, this message translates to:
  /// **'Remember your intention'**
  String get notifPrivateBody;

  /// No description provided for @channelPrayer.
  ///
  /// In en, this message translates to:
  /// **'Prayer'**
  String get channelPrayer;

  /// No description provided for @channelNiyyah.
  ///
  /// In en, this message translates to:
  /// **'Intention'**
  String get channelNiyyah;

  /// No description provided for @channelQuran.
  ///
  /// In en, this message translates to:
  /// **'Qur\'an'**
  String get channelQuran;

  /// No description provided for @channelHadith.
  ///
  /// In en, this message translates to:
  /// **'Hadith'**
  String get channelHadith;

  /// No description provided for @channelDhikr.
  ///
  /// In en, this message translates to:
  /// **'Dhikr'**
  String get channelDhikr;

  /// No description provided for @channelGoodDeeds.
  ///
  /// In en, this message translates to:
  /// **'Good deeds'**
  String get channelGoodDeeds;

  /// No description provided for @channelIslamicEvents.
  ///
  /// In en, this message translates to:
  /// **'Islamic events'**
  String get channelIslamicEvents;

  /// No description provided for @channelPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get channelPersonal;
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
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
