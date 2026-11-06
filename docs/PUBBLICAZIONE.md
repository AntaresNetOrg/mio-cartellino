# Pubblicare Mio Cartellino sugli store

L'app è pronta per i test: su iOS puoi distribuirla subito con TestFlight ai tester interni. Per Android serve prima un dispositivo fisico, e per la pubblicazione aperta restano i due punti qui sotto.

Requisiti verificati sulle pagine ufficiali il 5 novembre 2026: controllali di nuovo se passa molto tempo.

## Cosa è già pronto

| Cosa | Dove |
|---|---|
| Icone iOS e Android | `ios/`, `android/`, script `tool/generate_store_assets.py` |
| Icona App Store (1024 px) e Google Play (512 px) | `store/graphics/` |
| Immagine in evidenza Google Play (1024×500) | `store/graphics/` |
| Screenshot con dati fittizi | `store/screenshots/` |
| Testi delle schede | [store/SCHEDE.md](../store/SCHEDE.md) |
| Informativa privacy, anche dentro l'app | [PRIVACY.md](../PRIVACY.md) |
| Nome dell'app, versione 1.0.0, solo iPhone, target Android API 36 | progetto |
| Modalità demo con dati fittizi, per i revisori | Riepilogo → **Prova con dati dimostrativi**, su un'installazione senza dati |
| Firma Android per Google Play | `android/app/build.gradle.kts`: manca solo la chiave |

## Punti da risolvere prima

Nessuno blocca i tester interni di TestFlight. Tutti riguardano la pubblicazione aperta.

1. **Riferimenti all'Ateneo.** L'icona non usa il sigillo né altri elementi dell'Università. La scheda però cita l'Università di Salerno per spiegare a chi serve l'app, quindi l'avviso "non è un servizio ufficiale" deve restare. Prima di pubblicare, chiedi comunque conferma all'Ateneo.
2. **Accettazione della modalità demo.** Con SPID e CIE non si può fornire un account condiviso, quindi l'app include una demo con dati fittizi. Apple accetta una demo al posto dell'account solo per obblighi legali o di sicurezza e con la sua [approvazione preventiva](https://developer.apple.com/app-store/review/guidelines/): chiedila prima di inviare, spiegando il motivo. Google chiede [credenziali funzionanti](https://support.google.com/googleplay/android-developer/answer/14151465), quindi la demo potrebbe non bastare: se la rifiuta, serve un'utenza di prova fornita dall'Ateneo. Allega anche un breve video del login e del download reali, perché nella demo i revisori non vedono questa parte.

## 1. Test su iOS con TestFlight

**Una tantum: crea l'app su App Store Connect**

1. Accedi ad [App Store Connect](https://appstoreconnect.apple.com) → **App** → **+** → **Nuova app**.
2. Compila: piattaforma iOS, nome `Mio Cartellino`, lingua Italiano, bundle ID `it.bruand81.cartellinoUnisaMobile`, SKU `mio-cartellino`. Il bundle ID non si può più cambiare dopo il primo caricamento.

**Compila e carica la build**

```sh
PATH=/usr/bin:/bin:/usr/sbin:/sbin /opt/homebrew/share/flutter/bin/flutter build ipa
```

Il `PATH` ridotto serve su questo Mac: l'`rsync` di Homebrew è incompatibile con quello usato da Xcode, e il semplice `flutter build ipa` fallisce con `exportArchive Copy failed`. Adatta il percorso di Flutter se è diverso.

Il file si trova in `build/ios/ipa/`. Trascinalo nell'app **Transporter** del Mac, oppure apri `build/ios/archive/Runner.xcarchive` in Xcode e usa **Distribute App**. La build compare in TestFlight dopo l'elaborazione di Apple.

**Scegli i tester**

| | [Interni](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/) | [Esterni](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/) |
|---|---|---|
| Chi sono | Utenti del tuo team App Store Connect | Chiunque, via email o link pubblico |
| Quanti | Fino a 100 | Fino a 10.000 |
| Revisione Apple | Non indicata per i tester interni | La prima build richiede una revisione completa |
| Informazioni richieste | Nessuna | Descrizione, cosa provare, email per i commenti |

Una build resta provabile per [90 giorni](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).

Per il tuo collega usa i tester interni: aggiungilo in **Utenti e accessi**, con accesso a questa app, poi nel gruppo in TestFlight. Installerà prima l'app TestFlight. Al primo download deve vedere il proprio nome in "Cartellino di…". Controlla anche che i suoi numeri coincidano con il portale.

## 2. Test su Android con Google Play

**Una tantum: crea l'account e la chiave**

1. Registrati su [Play Console](https://play.google.com/console). Costa [25 dollari una tantum](https://support.google.com/googleplay/android-developer/answer/6112435) e può richiedere documento e carta di credito. Per gli account personali serve anche la [verifica con un dispositivo Android fisico](https://support.google.com/googleplay/android-developer/answer/14316361), con Android 10 o successivo: senza un telefono Android questo passaggio è bloccato.
2. Crea la chiave di caricamento, fuori dal repository:

    ```sh
    keytool -genkey -v -keystore ~/cartellino-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
    ```

3. Crea `android/key.properties`, che git ignora già, sostituendo i valori:

    ```properties
    storePassword=LA_TUA_PASSWORD
    keyPassword=LA_TUA_PASSWORD
    keyAlias=upload
    storeFile=/Users/TUO_UTENTE/cartellino-upload.jks
    ```

4. Salva chiave e password in un posto sicuro, come un gestore di password. Non vanno mai su GitHub.

**Compila e carica la build**

```sh
flutter build appbundle
```

Il file è `build/app/outputs/bundle/release/app-release.aab`. In Play Console crea l'app (`Mio Cartellino`, app, gratuita), poi caricalo in **Test** → **Test interno**. Accetta la [firma dell'app di Google Play](https://support.google.com/googleplay/android-developer/answer/9842756): per le nuove app le chiavi le genera Google.

**Scegli i tester**

| [Canale](https://support.google.com/googleplay/android-developer/answer/14151465) | Per chi | Note |
|---|---|---|
| Test interno | Fino a 100 persone scelte | Build disponibile quasi subito, senza completare la scheda |
| Test chiuso | Persone scelte | Scheda completa; serve per ottenere la produzione |
| Test aperto | Chiunque | Solo dopo l'accesso alla produzione |

## 3. Pubblicazione su App Store

1. **Risolvi i punti** indicati sopra, in particolare l'approvazione della demo.
2. **Pubblica l'informativa.** Il repository GitHub deve essere pubblico, altrimenti l'URL della privacy non funziona. Se il nome o l'account sono diversi da `AntaresNetOrg/mio-cartellino`, aggiorna gli URL in `store/SCHEDE.md`.
3. **Compila la scheda** con i testi di `store/SCHEDE.md`.
4. **Carica gli screenshot** da `store/screenshots/app-store/` (1320×2868). Se App Store Connect chiede anche la taglia media, usa `store/screenshots/app-store-6.3/` (1206×2622).
5. **Compila la privacy dell'app:** "non raccogliamo dati". Per Apple i dati [trattati solo sul dispositivo](https://developer.apple.com/app-store/app-privacy-details/) non sono "raccolti".
6. **Controlla la crittografia.** In `Info.plist` è dichiarato `ITSAppUsesNonExemptEncryption = false`, perché l'app usa solo l'HTTPS del sistema. Non ho potuto verificarlo sulla pagina Apple, e la valutazione [spetta a te](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/): rileggi le domande sull'esportazione.
7. **Scegli la distribuzione.** Se l'app serve solo al personale, valuta la [distribuzione non in elenco](https://developer.apple.com/support/unlisted-app-distribution/): non compare nelle ricerche e si apre solo con il link diretto, ma chi ha il link può scaricarla. Va richiesta ad Apple, non vale per app in beta e passa comunque dalla revisione.
8. **Invia per la revisione**, con le note di `store/SCHEDE.md` e il video del login.

Rischi noti: Apple può contestare un'app che [non va oltre un sito web](https://developer.apple.com/app-store/review/guidelines/), mentre qui la scheda Uscita e il riepilogo aggiungono funzioni proprie. Per il login con SPID e CIE, la regola 4.8 esenta i sistemi di identità governativi.

## 4. Pubblicazione su Google Play

1. **Completa il test chiuso, se l'account è personale.** Se è stato creato dopo il 13 novembre 2023 servono [almeno 12 tester iscritti per 14 giorni consecutivi](https://support.google.com/googleplay/android-developer/answer/14151465). Solo dopo puoi chiedere l'accesso alla produzione dalla Dashboard: la verifica di solito richiede fino a 7 giorni. Chi si ritira prima dei 14 giorni non conta. La pagina non cita gli account di organizzazione: se pubblicherà l'Ateneo, controlla il suo caso.
2. **Compila la scheda** con i testi di `store/SCHEDE.md`, l'icona da 512 px, l'immagine in evidenza e gli screenshot in `store/screenshots/google-play/`.
3. **Compila "Contenuti dell'app":**
    - [Sicurezza dei dati](https://support.google.com/googleplay/android-developer/answer/10787469): è obbligatoria anche se l'app non raccoglie nulla, e i dati trattati solo sul dispositivo non vanno dichiarati.
    - [Informativa privacy](https://support.google.com/googleplay/android-developer/answer/9859455): URL pubblico, senza login e non in PDF.
    - [Accesso all'app](https://support.google.com/googleplay/android-developer/answer/9859455): istruzioni per i revisori sulla demo, con il video del login.
    - Classificazione dei contenuti e pubblico di destinazione.
4. **Invia:** **Produzione** → crea una release → revisione. Il target [API 36](https://support.google.com/googleplay/android-developer/answer/11926878) richiesto dal 31 agosto 2026 è già impostato: ricontrollalo a ogni aggiornamento di Flutter.

## 5. Aggiornamenti successivi

1. In `pubspec.yaml` aumenta la versione: `1.0.1+2`. Il numero dopo il `+` deve crescere a ogni caricamento, anche per le sole build di test.
2. Verifica e compila:

    ```sh
    flutter analyze && flutter test
    PATH=/usr/bin:/bin:/usr/sbin:/sbin /opt/homebrew/share/flutter/bin/flutter build ipa
    flutter build appbundle
    ```

3. Prova la build release sul telefono: una build di debug non si apre dalla Home, senza `flutter run`.
4. Carica su TestFlight e sul test interno, poi promuovi la stessa build in produzione e scrivi le novità.
5. Se la schermata è cambiata, rifai gli screenshot: devono mostrare solo dati fittizi, mai i tuoi.
