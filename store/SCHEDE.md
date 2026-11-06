# Testi per le schede degli store

Da copiare in App Store Connect e Google Play Console. La procedura è in [docs/PUBBLICAZIONE.md](../docs/PUBBLICAZIONE.md).

## Testi comuni

**Nome:** Mio Cartellino

**Descrizione completa** (App Store e Google Play):

```text
Mio Cartellino aiuta il personale dell'Università di Salerno a controllare presenze e orario di uscita dal telefono.

Riepilogo
Scarica il tuo cartellino da presenze.unisa.it accedendo con SPID o CIE, poi consulta in un colpo d'occhio:
• saldo ore del mese;
• eccezioni del mese;
• riposi compensativi;
• ferie, festività soppresse e permessi.

Uscita prevista
Inserisci le timbrature di oggi e ottieni l'orario di uscita, considerando l'inizio del conteggio alle 07:50 e le assenze intermedie. Puoi anche scegliere di usare il credito o recuperare il debito. L'app ti avvisa quando serve un permesso e quando superi le 19:50.

Privacy
I dati restano sul tuo telefono. L'app non ha un server, non salva username o password e non contiene pubblicità né strumenti di tracciamento.

Avviso
Questa app non è un servizio ufficiale dell'Università di Salerno. I calcoli sono indicativi: per i dati ufficiali fa sempre fede il portale presenze.

Per usare il download serve un'utenza del personale dell'Università di Salerno abilitata a presenze.unisa.it.
```

## App Store Connect

| Campo | Testo |
|---|---|
| Lingua principale | Italiano |
| Sottotitolo | Presenze e uscita prevista |
| Testo promozionale | Saldo del mese, riposi compensativi, ferie e orario di uscita previsto: il tuo cartellino sul telefono. I dati restano sul dispositivo. |
| Parole chiave | cartellino,presenze,timbrature,orario,uscita,saldo,ore,riposi,ferie,permessi |
| URL assistenza | https://github.com/AntaresNetOrg/mio-cartellino/issues |
| URL privacy | https://github.com/AntaresNetOrg/mio-cartellino/blob/main/PRIVACY.md |
| Categoria | Produttività; secondaria: Economia |
| Copyright | 2026 Andrea Bruno |
| Novità (dalla seconda versione) | Da scrivere a ogni aggiornamento |

**Privacy dell'app:** "No, non raccogliamo dati da questa app".

**Note per la revisione** (inserisci il link al video prima di inviare):

```text
The app is for staff of the University of Salerno (Italy). It downloads the user's own attendance record from https://presenze.unisa.it after a login inside a WebView.

Login uses SPID or CIE, the Italian government digital identity systems, and requires a staff account of the university. These are personal identities, so a shared demo account can't be provided.

To test the app without a login, use the built-in demo mode:
1. Open the "Riepilogo" tab on a fresh install.
2. Tap "Prova con dati dimostrativi". All data shown is fictitious.
3. Open the "Uscita" tab and tap "Entrata adesso" to see the expected exit time, then try "Uso credito" and "Recupero debito".
4. "Esci dalla demo" removes the demo data.

Video of the real login and download flow: [LINK]

The app has no backend. All data stays on the device.
```

## Google Play Console

| Campo | Testo |
|---|---|
| Lingua predefinita | Italiano (it-IT) |
| Descrizione breve | Saldo ore, riposi, ferie e orario di uscita: il tuo cartellino sul telefono. |
| Sito web | https://github.com/AntaresNetOrg/mio-cartellino |
| Email di contatto | info@antaresnet.org |
| Norme sulla privacy | https://github.com/AntaresNetOrg/mio-cartellino/blob/main/PRIVACY.md |
| Categoria | Produttività |
| Tipo | App, gratuita |

**Sicurezza dei dati:** l'app non raccoglie né condivide dati utente, perché tutto resta sul dispositivo.

**Accesso all'app:** indica che l'accesso è limitato e incolla nelle istruzioni le stesse note di App Store.
