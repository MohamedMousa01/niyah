"""Genera i file ARB (lib/l10n/app_*.arb) da una sola tabella.

Tenere i testi qui, una riga per chiave con le 4 lingue affiancate, evita che
una traduzione resti indietro. Dopo una modifica: python3 tool/make_arb.py
Le traduzioni en/fr/ar vanno riviste da madrelingua prima della pubblicazione.
"""
import json
from pathlib import Path

LANGS = ["it", "en", "fr", "ar"]

# chiave: (it, en, fr, ar[, segnaposti])
S = {
    "appTitle": ("Niyah", "Niyah", "Niyah", "نيّة"),
    "tagline": ("Rinnova la tua intenzione.", "Renew your intention.", "Renouvelle ton intention.", "جدّد نيّتك."),
    "navHome": ("Home", "Home", "Accueil", "الرئيسية"),
    "navNotifications": ("Le mie notifiche", "My notifications", "Mes notifications", "إشعاراتي"),
    "navStoPer": ("Sto per…", "I'm about to…", "Je vais…", "سأقوم بـ…"),
    "navSettings": ("Impostazioni", "Settings", "Réglages", "الإعدادات"),
    "homeNotificationsBody": (
        "Scegli quando ricordare la tua intenzione.",
        "Choose when to be reminded of your intention.",
        "Choisis quand te rappeler ton intention.",
        "اختر متى تتذكّر نيّتك.",
    ),
    "homeStoPerBody": (
        "Prima di un'azione, rinnova l'intenzione.",
        "Before an action, renew your intention.",
        "Avant une action, renouvelle ton intention.",
        "قبل أي عمل، جدّد نيّتك.",
    ),
    "homeSettingsBody": (
        "Lingua, Non disturbare, pausa.",
        "Language, quiet hours, pause.",
        "Langue, ne pas déranger, pause.",
        "اللغة، أوقات الهدوء، الإيقاف المؤقت.",
    ),
    "next": ("Avanti", "Next", "Suivant", "التالي"),
    "back": ("Indietro", "Back", "Retour", "رجوع"),
    "start": ("Inizia", "Start", "Commencer", "ابدأ"),
    "notNow": ("Non ora", "Not now", "Pas maintenant", "ليس الآن"),
    "save": ("Salva", "Save", "Enregistrer", "حفظ"),
    "cancel": ("Annulla", "Cancel", "Annuler", "إلغاء"),
    "onboardingWelcomeTitle": ("Benvenuto in Niyah", "Welcome to Niyah", "Bienvenue dans Niyah", "مرحبًا بك في نيّة"),
    "onboardingWelcomeBody": (
        "Piccoli promemoria per rinnovare l'intenzione durante la giornata. Funziona anche offline, senza pubblicità e senza tracciamento.",
        "Small reminders to renew your intention throughout the day. Works offline, with no ads and no tracking.",
        "De petits rappels pour renouveler ton intention au fil de la journée. Fonctionne hors ligne, sans publicité ni pistage.",
        "تذكيرات صغيرة لتجديد النيّة خلال يومك. يعمل دون اتصال، بلا إعلانات ولا تتبّع.",
    ),
    "onboardingLanguageTitle": ("Scegli la lingua", "Choose your language", "Choisis ta langue", "اختر اللغة"),
    "onboardingNotificationsTitle": ("Notifiche", "Notifications", "Notifications", "الإشعارات"),
    "onboardingNotificationsBody": (
        "Niyah ti invia solo i promemoria che scegli tu, negli orari che decidi. Puoi cambiarli o metterli in pausa quando vuoi.",
        "Niyah only sends the reminders you choose, at the times you decide. You can change or pause them at any time.",
        "Niyah n'envoie que les rappels que tu choisis, aux heures que tu décides. Tu peux les modifier ou les mettre en pause à tout moment.",
        "لا يرسل نيّة إلا التذكيرات التي تختارها، في الأوقات التي تحدّدها. يمكنك تغييرها أو إيقافها مؤقتًا متى شئت.",
    ),
    "allowNotifications": ("Consenti le notifiche", "Allow notifications", "Autoriser les notifications", "السماح بالإشعارات"),
    "sectionSuggested": ("Suggeriti da Niyah", "Suggested by Niyah", "Suggérés par Niyah", "مقترحات نيّة"),
    "sectionContent": ("Contenuti islamici", "Islamic content", "Contenus islamiques", "محتوى إسلامي"),
    "sectionWeekly": ("Settimanali e stagionali", "Weekly and seasonal", "Hebdomadaires et saisonniers", "أسبوعية وموسمية"),
    "contentComingSoon": (
        "Versetti e hadith arrivano solo dopo la verifica delle fonti. Questa sezione si attiverà quando saranno disponibili.",
        "Verses and hadith are added only after their sources are verified. This section will open when they are available.",
        "Les versets et hadiths ne sont ajoutés qu'après vérification des sources. Cette section s'ouvrira quand ils seront disponibles.",
        "لا تُضاف الآيات والأحاديث إلا بعد التحقق من مصادرها. سيُفتح هذا القسم عند توفّرها.",
    ),
    "notificationsOff": (
        "Le notifiche di Niyah sono disattivate su questo telefono.",
        "Niyah notifications are turned off on this phone.",
        "Les notifications de Niyah sont désactivées sur ce téléphone.",
        "إشعارات نيّة معطّلة على هذا الهاتف.",
    ),
    "openSettings": ("Apri impostazioni", "Open settings", "Ouvrir les réglages", "فتح الإعدادات"),
    "everyDayAt": ("Ogni giorno alle {time}", "Every day at {time}", "Tous les jours à {time}", "كل يوم الساعة {time}", ["time"]),
    "daysAt": ("{days} alle {time}", "{days} at {time}", "{days} à {time}", "{days} الساعة {time}", ["days", "time"]),
    "betweenTimes": ("Tra le {start} e le {end}", "Between {start} and {end}", "Entre {start} et {end}", "بين {start} و{end}", ["start", "end"]),
    "pauseCustom": ("Fino a…", "Until…", "Jusqu'à…", "حتى…"),
    "time": ("Orario", "Time", "Heure", "الوقت"),
    "days": ("Giorni", "Days", "Jours", "الأيام"),
    "reminderOn": ("Attivo", "On", "Activé", "مفعّل"),
    "reminderOff": ("Disattivato", "Off", "Désactivé", "معطّل"),
    "mutedByQuietHours": (
        "Questo orario cade nella fascia Non disturbare: la notifica non arriverà.",
        "This time falls within quiet hours: the notification won't arrive.",
        "Cette heure tombe pendant « Ne pas déranger » : la notification n'arrivera pas.",
        "هذا الوقت ضمن أوقات الهدوء: لن يصل الإشعار.",
    ),
    "errorDaysRequired": ("Scegli almeno un giorno.", "Choose at least one day.", "Choisis au moins un jour.", "اختر يومًا واحدًا على الأقل."),
    "stoPerEmpty": (
        "I contenuti per questo momento arriveranno dopo la verifica delle fonti.",
        "Content for this moment will arrive once its sources are verified.",
        "Les contenus pour ce moment arriveront après la vérification des sources.",
        "سيصل محتوى هذه اللحظة بعد التحقق من مصادره.",
    ),
    "settingsLanguage": ("Lingua", "Language", "Langue", "اللغة"),
    "settingsQuietHours": ("Non disturbare", "Quiet hours", "Ne pas déranger", "أوقات الهدوء"),
    "quietHoursOff": ("Disattivato", "Off", "Désactivé", "معطّل"),
    "quietHoursRange": ("Dalle {start} alle {end}", "From {start} to {end}", "De {start} à {end}", "من {start} إلى {end}", ["start", "end"]),
    "quietHoursFrom": ("Dalle", "From", "De", "من"),
    "quietHoursTo": ("Alle", "To", "À", "إلى"),
    "quietModeSkip": ("Salta le notifiche nella fascia", "Skip notifications in this window", "Ignorer les notifications pendant cette plage", "تخطَّ الإشعارات خلال هذه الفترة"),
    "quietModeShift": ("Spostale alla fine della fascia", "Move them to the end of the window", "Les reporter à la fin de la plage", "أجّلها إلى نهاية الفترة"),
    "settingsPause": ("Pausa", "Pause", "Pause", "إيقاف مؤقت"),
    "pauseNone": ("Notifiche attive", "Notifications on", "Notifications actives", "الإشعارات مفعّلة"),
    "pausedUntil": ("In pausa fino a {when}", "Paused until {when}", "En pause jusqu'à {when}", "متوقفة حتى {when}", ["when"]),
    "pause1h": ("Per 1 ora", "For 1 hour", "Pendant 1 heure", "لمدة ساعة"),
    "pauseToday": ("Fino a stasera", "Until tonight", "Jusqu'à ce soir", "حتى الليلة"),
    "pauseTomorrow": ("Fino a domani mattina", "Until tomorrow morning", "Jusqu'à demain matin", "حتى صباح الغد"),
    "resume": ("Riprendi le notifiche", "Resume notifications", "Reprendre les notifications", "استئناف الإشعارات"),
    "settingsPermission": ("Permesso notifiche", "Notification permission", "Autorisation des notifications", "إذن الإشعارات"),
    "permissionGranted": ("Consentite", "Allowed", "Autorisées", "مسموح بها"),
    "permissionDenied": ("Non consentite", "Not allowed", "Non autorisées", "غير مسموح بها"),
    "settingsAbout": ("Informazioni", "About", "À propos", "حول التطبيق"),
    "aboutBody": (
        "Niyah è gratuita, senza pubblicità e senza tracciamento. I contenuti islamici vengono pubblicati solo dopo la verifica delle fonti.",
        "Niyah is free, with no ads and no tracking. Islamic content is published only after its sources are verified.",
        "Niyah est gratuite, sans publicité ni pistage. Les contenus islamiques ne sont publiés qu'après vérification des sources.",
        "نيّة مجاني، بلا إعلانات ولا تتبّع. لا يُنشر المحتوى الإسلامي إلا بعد التحقق من مصادره.",
    ),
    "aboutVersion": ("Versione {version}", "Version {version}", "Version {version}", "الإصدار {version}", ["version"]),
    "aboutLicenses": ("Licenze", "Licenses", "Licences", "التراخيص"),
    "genericError": ("Qualcosa non ha funzionato. Riprova.", "Something went wrong. Please try again.", "Un problème est survenu. Réessaie.", "حدث خطأ. حاول مرة أخرى."),
    # Testi delle notifiche (usati dal motore, nella lingua attiva)
    "prayerFajr": ("Fajr", "Fajr", "Fajr", "الفجر"),
    "prayerDhuhr": ("Dhuhr", "Dhuhr", "Dhuhr", "الظهر"),
    "prayerAsr": ("Asr", "Asr", "Asr", "العصر"),
    "prayerMaghrib": ("Maghrib", "Maghrib", "Maghrib", "المغرب"),
    "prayerIsha": ("Isha", "Isha", "Isha", "العشاء"),
    "notifPrayerAtTime": ("È l'ora di {prayer}", "It's time for {prayer}", "C'est l'heure de {prayer}", "حان وقت {prayer}", ["prayer"]),
    "notifPrayerBefore": ("{prayer} tra {minutes} minuti", "{prayer} in {minutes} minutes", "{prayer} dans {minutes} minutes", "{prayer} بعد {minutes} دقيقة", ["prayer", "minutes"]),
    "notifQuranTitle": ("Corano", "Qur'an", "Coran", "القرآن"),
    "notifHadithTitle": ("Hadith", "Hadith", "Hadith", "حديث"),
    "notifDhikrTitle": ("Dhikr", "Dhikr", "Dhikr", "ذكر"),
    "notifTapToRead": ("Tocca per leggere", "Tap to read", "Touche pour lire", "اضغط للقراءة"),
    "notifRefreshBody": (
        "Apri Niyah per continuare a ricevere i promemoria.",
        "Open Niyah to keep receiving your reminders.",
        "Ouvre Niyah pour continuer à recevoir tes rappels.",
        "افتح نيّة لتستمر في تلقّي تذكيراتك.",
    ),
    "notifPrivateBody": ("Ricorda la tua intenzione", "Remember your intention", "Souviens-toi de ton intention", "تذكّر نيّتك"),
    "channelPrayer": ("Preghiera", "Prayer", "Prière", "الصلاة"),
    "channelNiyyah": ("Niyyah", "Niyyah", "Niyyah", "النيّة"),
    "channelQuran": ("Corano", "Qur'an", "Coran", "القرآن"),
    "channelHadith": ("Hadith", "Hadith", "Hadith", "الحديث"),
    "channelDhikr": ("Dhikr", "Dhikr", "Dhikr", "الذكر"),
    "channelGoodDeeds": ("Buone azioni", "Good deeds", "Bonnes actions", "الأعمال الصالحة"),
    "channelIslamicEvents": ("Eventi islamici", "Islamic events", "Événements islamiques", "المناسبات الإسلامية"),
    "channelPersonal": ("Promemoria personali", "Personal reminders", "Rappels personnels", "تذكيرات شخصية"),
}


def main() -> None:
    out = Path(__file__).resolve().parent.parent / "lib" / "l10n"
    out.mkdir(parents=True, exist_ok=True)
    for i, lang in enumerate(LANGS):
        arb: dict = {"@@locale": lang}
        for key, row in S.items():
            arb[key] = row[i]
            if lang == "it" and len(row) > 4:
                arb[f"@{key}"] = {"placeholders": {p: {"type": "String"} for p in row[4]}}
        (out / f"app_{lang}.arb").write_text(json.dumps(arb, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{len(S)} chiavi × {len(LANGS)} lingue → {out}")


if __name__ == "__main__":
    main()
