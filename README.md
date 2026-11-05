# Cartellino UniSA — mobile

App iOS/Android companion di [CartellinoUniSA](https://github.com/staffDiUnisa/CartellinoUniSA):
scarica il cartellino da presenze.unisa.it (login SPID o CIE), mostra il riepilogo del mese
(saldo, eccezioni, riposi compensativi, ferie/PMF) e calcola l'orario di uscita previsto.

## Primo avvio dello sviluppo

```sh
cd cartellino_unisa_mobile
flutter pub get
flutter analyze
flutter test
code .
```

Poi in VS Code: avvia "Cartellino UniSA (debug)" con un emulatore o un dispositivo collegato.
Dettagli di architettura, regole di calcolo e stato dei lavori in [CLAUDE.md](CLAUDE.md).

## Licenza

GPL-3.0, come il progetto desktop.
