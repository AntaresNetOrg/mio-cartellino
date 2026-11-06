# Mio Cartellino

App iOS/Android companion di [CartellinoUniSA](https://github.com/staffDiUnisa/CartellinoUniSA):
scarica il cartellino da presenze.unisa.it (login SPID o CIE), mostra il riepilogo del mese
(saldo, eccezioni, riposi compensativi, ferie/PMF) e calcola l'orario di uscita previsto.

## Primo avvio dello sviluppo

```sh
cd mio-cartellino
flutter pub get
flutter analyze
flutter test
code .
```

Poi in VS Code: avvia "Mio Cartellino (debug)" con un emulatore o un dispositivo collegato.
Dettagli di architettura, regole di calcolo e stato dei lavori in [CLAUDE.md](CLAUDE.md).
Per pubblicare l'app segui [docs/PUBBLICAZIONE.md](docs/PUBBLICAZIONE.md). Informativa: [PRIVACY.md](PRIVACY.md).

## Licenza

[MIT](LICENSE).
