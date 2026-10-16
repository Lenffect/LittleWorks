# Little Works — bouwplan v1 (16 okt 2026)

## Besluiten
| Onderwerp | Besluit |
|---|---|
| Doel | Leerproject en eigen gebruik. Geld later, quitte spelen is mooi meegenomen. |
| Team | Solo. |
| Markt | Dutch first (urencriterium, BTW, NL-CSV). Internationaal later. |
| Apps | Drie: tikk., moola., brix. Remi wordt een module in brix (wachten op feedback/betaling). |
| Distributie | Alleen eigen Mac. Geen notarisatie, geen App Store, geen prijs. |
| Sync/iPhone | Uitgesteld. CloudKit vraagt betaald Apple Developer-account (€99/jr). Tot die tijd: JSON-backup. |
| Moola-bron | Eigen gevibecoded dashboard, handmatig ingevoerde data. Handmatig invoeren is voor eigen gebruik prima. |

## Architectuur
- Eén repo (monorepo), Swift + SwiftUI, minimum macOS 14.
- `LittleWorksCore` (Swift Package): modellen, timer-engine, afronding, CSV, design tokens. Geen UI, volledig unit-testbaar.
- `Tikk` (menubalk-app), later `Brix` en `Moola` (venster-apps) gebruiken dezelfde package.
- Opslag: SwiftData. Modellen CloudKit-compatibel houden (defaults of optionals, geen unique constraints) zodat sync later kan.
- `TimeEntry` krijgt nu al `projectId: UUID?` voor brix.

## Tikk — Fase 1 (kern, alleen dit)
1. Xcode-project + `LittleWorksCore` package + test-target.
2. Timer-engine met tests: start, stop, wissel, nooit twee actief, middernacht-splitsing.
3. SwiftData-opslag: `Client`, `TimeEntry`, `lastSeenAt`.
4. `MenuBarExtra` met popover: klantenlijst, klik = start/stop/wissel, lopende tijd.
5. Klant toevoegen, hernoemen, archiveren.
6. Herstel na crash of herstart ("laatst gezien" elke minuut).
7. Slaapstand-vraag bij terugkomst (> 5 min).
8. Dag- en weektotaal in de popover.
9. Launch at login.

**Klaar als:** je het één week zelf gebruikt zonder één verkeerde registratie.

## Tikk — Fase 2 (nuttig)
1. Overzichtsvenster: dag/week/maand, filter per klant.
2. Registraties aanpassen, toevoegen, verwijderen (met validatie).
3. CSV-export (NL-notatie).
4. Notitie per registratie.
5. **Urencriterium-balk:** voortgang naar 1.225 uur per jaar. Controleer eerst de actuele regels bij de Belastingdienst.
6. JSON-backup.

## Uitgesteld (pas na eigen gebruik)
Afronden per klant, dag-/weekdoelen, omzet, herinnering, sneltoets, Tikko-animaties, onboarding, merkafwerking.

## Daarna
| Fase | Wat |
|---|---|
| 3 | Brix MVP: project, vaste prijs, geschatte uren, Tikk-koppeling, effectief uurtarief, "wachten op"-lijst (ex-Remi). |
| 4 | Moola: dashboard-audit (datavelden, wat je echt gebruikt), dan herbouwen in SwiftUI. Daarna reserve-potten (BTW, inkomstenbelasting). |
| 5 | iPhone/sync, alleen als je het mist. |

## Openstaand
- Merk- en domeincheck (Tikk, moola, brix) — pas nodig voor delen of verkopen.
- Dashboard exporteren of beschrijven voor de Moola-audit.
