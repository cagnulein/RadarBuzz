# RadarBuzz

Campo dati Garmin Connect IQ che legge il radar bici ANT+ e, quando rileva almeno un veicolo dietro, fa vibrare il dispositivo una volta al secondo con pattern diversi in base alla distanza del target piu vicino.

## Cosa fa

- `CLEAR`: nessun target dietro
- `SCAN`: radar in ricerca
- `PAIR`: radar non disponibile o non associato
- `12m 3`: target piu vicino a 12 metri, 3 target totali

Pattern vibrazione:

- oltre 25 m: impulso singolo
- tra 10 m e 25 m: doppio impulso
- sotto 10 m: triplo impulso forte

Le soglie `10 m` e `25 m` ora sono configurabili dalle impostazioni dell'app.

## Limiti importanti

- Funziona come `datafield`, quindi va aggiunto a una schermata di un'attivita bici.
- Richiede un dispositivo Connect IQ che supporti sia `Toybox.AntPlus.BikeRadar` sia `Toybox.Attention.vibrate`.
- Su molti Edge la vibrazione non esiste: il progetto qui e pensato soprattutto per orologi compatibili.
- Sui Forerunner i pattern di vibrazione possono non essere distinti: la documentazione Garmin dice che la vibrazione potrebbe usare sempre lo stesso duty cycle.

## Device inclusi nel manifest

Il `manifest.xml` ora include un set molto ampio di dispositivi con supporto radar e vibrazione.

Scelta intenzionale:

- inclusi: orologi e wearable che, secondo le API Garmin, supportano `BikeRadarListener` e vibrazione
- esclusi: gli `Edge`, anche se leggono il radar, perche non sono coerenti con il requisito "mi vibri di continuo"

Nota pratica:

- il product id `venu445mm` copre anche il gruppo hardware `Venu 4 45mm / D2 Air X15` mostrato nella documentazione Garmin

## GitHub Actions

Ho aggiunto il workflow [build-garmin-iq.yml](/mnt/c/Users/violarob/Documents/New%20project/.github/workflows/build-garmin-iq.yml) che costruisce `dist/RadarBuzz.iq` e lo pubblica come artifact.

Il workflow usa:

- SDK Garmin `9.1.0`
- `connect-iq-sdk-manager-cli` per automatizzare download SDK + device library in CI
- firma del pacchetto con la tua developer key

### Secret richiesti

- `GARMIN_USERNAME`: username del tuo account Garmin/Connect IQ
- `GARMIN_PASSWORD`: password del tuo account Garmin/Connect IQ
- `CIQ_AGREEMENT_HASH`: hash dell'accordo SDK Garmin accettato
- `CIQ_DEVELOPER_KEY_DER_BASE64`: contenuto base64 della tua chiave `developer_key.der`

### Come ottenere la developer key DER

La documentazione del SDK Garmin include anche la procedura OpenSSL:

```bash
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt
base64 -w 0 developer_key.der
```

L'output dell'ultimo comando va messo nel secret `CIQ_DEVELOPER_KEY_DER_BASE64`.

### Come ottenere `CIQ_AGREEMENT_HASH`

Il workflow si aspetta l'hash dell'accordo Garmin gia letto e approvato. Con il tool CLI usato in CI puoi recuperarlo cosi, in locale:

```bash
connect-iq-sdk-manager agreement view
```

Dopo aver letto l'accordo, usa l'hash mostrato come valore del secret `CIQ_AGREEMENT_HASH`.

## File principali

- `manifest.xml`
- `source/RadarBuzzApp.mc`
- `source/RadarBuzzView.mc`
- `.github/workflows/build-garmin-iq.yml`

## Come provarlo

1. Installa il Connect IQ SDK.
2. Apri la cartella del progetto in Visual Studio Code con l'estensione Monkey C.
3. Compila il data field per un dispositivo compatibile.
4. Associa il radar al dispositivo Garmin.
5. Aggiungi `RadarBuzz` a una pagina dati della tua attivita bici.

## Configurare le soglie

Puoi cambiare le due soglie distanza senza modificare il codice:

- `Soglia vicina (m)`: sotto questo valore parte il pattern forte a triplo impulso
- `Soglia media (m)`: sotto questo valore parte il pattern medio a doppio impulso

Se imposti valori non validi, l'app applica un fallback sicuro:

- `Soglia vicina` minima: `1 m`
- `Soglia media` deve essere maggiore della soglia vicina

Nel simulator puoi provarle da:

- `File > Edit Persistent Storage > Edit Application.Properties data`

Da li puoi cambiare `nearThresholdMeters` e `midThresholdMeters` e vedere subito il comportamento aggiornato.

## Note

Il progetto e pronto per build locali e build CI, ma la compilazione reale richiede comunque la libreria device Garmin e una developer key valida.
