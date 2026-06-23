# TODO

## Domani

- Provare il flusso `Per oggi basta` in uso reale: sessione attiva, nessuna sessione attiva, giornata gia chiusa.
- Verificare che la riga `Giornata chiusa` in Today sia chiara ma non invadente.
- Controllare la card `Chiusure giornata` nelle Stats con qualche giornata di dati reali.
- Valutare se il testo dei mood va bene o se renderlo piu sobrio/configurabile.
- Fare un giro manuale su sync dopo una chiusura giornata: Mac principale -> pull su altro Mac, se disponibile.
- Preparare release note brevi per questa versione.

## Prossimi giorni

- Introdurre un modello SwiftData dedicato `DayReview` per mood, pressione e nota di fine giornata.
- Migrare le chiusure attuali lette da `TimeEntry.notes` verso `DayReview`.
- Aggiornare sync server e DTO per sincronizzare `DayReview`.
- Aggiungere test per parsing/migrazione delle chiusure giornata.
- Disegnare una sezione `Appunti di oggi` leggera, collegata alla chiusura giornata.
- Valutare export manuale verso Note di macOS dopo che `DayReview` e stabile.
- Mantenere iOS in maintenance mode: build verde, niente nuove feature salvo compatibilita.
