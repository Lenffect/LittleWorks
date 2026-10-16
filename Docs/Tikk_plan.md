# Tikk.
### Your tiny timekeeper.

**Product & Development Briefing**  
Versie 1.1 — MVP

---

# 00. Besluiten (v1.1)

Deze besluiten gaan voor op de rest van het document.

| Onderwerp | Besluit |
|-----------|---------|
| Distributie | Eerst alleen voor eigen gebruik. Geen App Store, geen notarisatie. Publiek of deelbaar maken kan later. Houd de sandbox en `SMAppService` wel compatibel. |
| Slaapstand | Bij terugkomst na meer dan X minuten (standaard 5) vraagt Tikk: "Je was 2u weg. Meetellen?" Keuzes: meetellen, afkappen op het moment van weggaan, of stoppen. Vervangt de regel "slaaptijd telt standaard mee" in Feature 2. |
| Crash of herstart | Tikk slaat elke minuut een "laatst gezien"-tijdstip op. Bij opstarten met een open sessie vraagt Tikk: stoppen op het laatst geziene tijdstip, of doortellen tot nu. |
| Notitie | Elke registratie krijgt een optioneel veld `note`. Uit "Future ideas" naar de MVP. |
| Sneltoets | Globale sneltoets om de popover te openen en de laatste klant te starten of stoppen. Uit "Future ideas" naar de MVP. |
| Verwijderen | Een klant met uren kan alleen worden gearchiveerd. Een klant zonder uren kan worden verwijderd. |
| Roadmap | Fase 1 en 2 zijn samengevoegd tot één fase. Branding blijft fase 3, met eerst een systeemicoon. |
| Menubalk | Begin met `MenuBarExtra`. Als de lopende tijd naast het icoon niet goed werkt, ga naar `NSStatusItem` met `NSPopover`. |
| Persistence | SwiftData, minimum macOS 14. De timer-engine is onafhankelijk van SwiftData. |
| Afronden | Standaard op 15 minuten, altijd omhoog naar het volgende kwartier (0 minuten blijft 0). De afronding geldt per klant per dag over het totaal, niet per registratie. De opgeslagen tijden blijven altijd exact. De afronding wordt alleen toegepast in overzicht en export. Instelbaar: uit, 15 of 30 minuten, en per klant te overschrijven. |
| Pauze en doorgaan | Pauze stopt de registratie en onthoudt de klant. "Doorgaan" start een nieuwe registratie voor die klant, via de popover of een sneltoets. Dit is één functie, geen aparte pauzestatus in de engine. |
| Backup | Handmatige en automatische JSON-backup. Standaard één keer per dag naar een gekozen map, met de laatste 14 bewaard. Terugzetten via Settings. |
| Doelen | Optioneel dagdoel en weekdoel in uren. De popover toont een rustige voortgangsbalk. Geen meldingen of druk. |
| Omzet | Het overzicht toont per klant en per periode de omzet (afgeronde uren × uurtarief). Alleen voor klanten met een tarief. |
| Herinnering | Eén vriendelijke melding na 30 minuten actief zijn zonder lopende timer. Instelbaar, standaard uit tot het onboarding-scherm erom vraagt. Alleen tijdens werkdagen en werktijden. |
| Datumnavigatie | Vanuit "Today" en elke registratie kan de gebruiker met één klik naar die dag in het overzicht. |
| CSV | Nederlandse notatie als keuze: puntkomma als scheidingsteken, komma als decimaal, `dd-mm-jjjj`. Standaard aan. De CSV bevat zowel de exacte als de afgeronde duur. |

Aanpassingen aan het datamodel:

- `TimeEntry` krijgt `note: String?`.
- `Client` krijgt `roundingMinutes: Int?`. Bij `nil` geldt de globale instelling.
- Er komt een `lastSeenAt: Date` in de opgeslagen app-status voor het herstellen na een crash.
- De app-status onthoudt `lastClientId: UUID?` voor "Doorgaan".
- `AppSettings` krijgt `roundingMinutes`, `dailyGoalHours`, `weeklyGoalHours`, `reminderEnabled`, `reminderAfterMinutes`, `awayThresholdMinutes`, `backupFolder` en `csvDutchFormat`.

Aanpassing aan het CSV-voorbeeld:

```csv
Date,Client,Start,End,Duration,Rounded,Hours,Note
2026-10-12,Studio Noord,09:15,11:30,02:15,02:15,2.25,Homepage
```

Open punt: bij afronden per klant per dag kan het totaal van een dag een paar minuten afwijken van de som van de losse registraties. Het overzicht moet dat duidelijk tonen, bijvoorbeeld "2u 15m (exact 2u 12m)".

---

# 01. Het concept

## Wat is Tikk?

Tikk is een minimalistische macOS-app waarmee freelancers en zzp'ers hun gewerkte uren per klant kunnen bijhouden.

De app leeft volledig in de menubalk van macOS.

Geen grote applicatievensters. Geen ingewikkelde dashboards. Geen uitgebreide projectmanagementsoftware.

Gewoon een klein icoontje bovenin je scherm waarmee je binnen één klik een timer voor een klant kunt starten of stoppen.

**Het uitgangspunt:**

> Open je Mac. Klik op een klant. Werk. Klik nog een keer. Klaar.

Tikk houdt automatisch bij wanneer je bent begonnen, wanneer je bent gestopt en hoeveel tijd je hebt gewerkt.

Aan het einde van de dag, week of maand kun je eenvoudig zien hoeveel uur je aan welke klant hebt besteed.

### De belofte

**Time tracking without thinking about time tracking.**

Tikk moet zo eenvoudig zijn dat uren bijhouden nauwelijks nog als een taak voelt.

---

# 02. Productfilosofie

Tikk wordt gebouwd vanuit vijf principes.

### 1. One-click simplicity

Een timer starten of stoppen mag nooit meer dan één klik kosten vanuit het geopende menu.

Geen formulieren, bevestigingsschermen of extra stappen.

### 2. Always there, never in the way

Tikk leeft in de macOS-menubalk.

De app is altijd bereikbaar, maar vraagt nooit onnodig aandacht.

### 3. Small by design

Tikk probeert geen alles-in-één bedrijfssoftware te worden.

De app doet één ding uitzonderlijk goed: tijd bijhouden per klant.

### 4. Friendly, not corporate

Tikk heeft een vriendelijke, speelse identiteit.

Geen zakelijke SaaS-uitstraling, maar het gevoel van een zorgvuldig ontworpen indie-Mac-app.

### 5. Local first

Alle gegevens worden standaard lokaal op de Mac opgeslagen.

Geen account, cloudverbinding of abonnement nodig om de basisfunctionaliteit te gebruiken.

---

# 03. De doelgroep

### Primaire doelgroep

Freelancers en zelfstandigen die voor meerdere klanten werken.

Bijvoorbeeld:

- Designers
- Developers
- Creatieve freelancers
- Consultants
- Copywriters
- Marketingprofessionals
- Kleine zelfstandige bureaus

### Het probleem

Veel freelancers vergeten hun uren bij te houden omdat bestaande oplossingen te uitgebreid zijn.

Ze moeten een website openen, een project selecteren, een omschrijving invoeren of door meerdere schermen navigeren.

Daardoor worden uren achteraf gereconstrueerd en gaat factureerbare tijd verloren.

### De oplossing

Tikk maakt urenregistratie net zo eenvoudig als het aan- en uitzetten van een schakelaar.

---

# 04. De gebruikerservaring

## 4.1 Tikk in de menubalk

Na installatie verschijnt een klein Tikk-icoontje rechtsboven in de macOS-menubalk.

Bijvoorbeeld:

**Inactief**

`◉`

**Actief**

`◉  01:24`

De actieve timer kan optioneel naast het icoontje worden weergegeven.

Wanneer er geen timer actief is, blijft alleen het icoontje zichtbaar.

### Interactie

Een klik op het icoontje opent een compacte native macOS-popover.

Hierin staan alle klanten en de belangrijkste acties.

---

## 4.2 Het hoofdmenu

Voorbeeld van de interface:

```text
┌──────────────────────────────┐
│                              │
│  ● Tikk.             01:42:18│
│  Your tiny timekeeper.       │
│                              │
│  TRACKING                    │
│                              │
│  ● Studio Noord      01:42:18│
│  ○ Acme Agency               │
│  ○ Eigen werk                │
│  ○ Project Delta             │
│                              │
│  + Add client                │
│                              │
│  ──────────────────────────  │
│                              │
│  Today               04:35   │
│  This week          21:15   │
│                              │
│  ──────────────────────────  │
│                              │
│  ↗ View overview             │
│  ⚙ Settings                  │
│                              │
└──────────────────────────────┘
```

Dit is een functionele schets, geen definitief visueel ontwerp.

### Gedrag

**Klik op een inactieve klant:**
- Timer voor die klant start onmiddellijk.
- Het klanticoontje verandert naar actief.
- De tijd begint zichtbaar te lopen.
- De popover mag automatisch sluiten.

**Klik op de actieve klant:**
- Timer stopt onmiddellijk.
- De tijdregistratie wordt opgeslagen.
- De klant wordt weer inactief.

**Klik op een andere klant:**
- De huidige timer stopt automatisch.
- De nieuwe klanttimer start onmiddellijk.
- Er is nooit meer dan één actieve timer tegelijk.

Deze laatste functionaliteit is belangrijk.

Freelancers wisselen regelmatig tussen klanten. Dat moet zonder extra handelingen kunnen.

---

# 05. Core features — MVP

## Feature 1: Client management

Gebruikers kunnen eenvoudig klanten toevoegen.

Een klant bevat:

- Naam
- Kleur
- Optioneel uurtarief
- Aanmaakdatum
- Actief/gearchiveerd

### Interactie

Via `+ Add client` opent een kleine invoerinterface.

De gebruiker vult een naam in en kiest eventueel een kleur.

Daarna verschijnt de klant direct in het hoofdmenu.

Klanten kunnen worden hernoemd, gearchiveerd en verwijderd.

Bij verwijderen moet duidelijk worden aangegeven wat er met bestaande urenregistraties gebeurt.

**MVP-keuze:** bestaande urenregistraties blijven behouden wanneer een klant wordt gearchiveerd.

---

## Feature 2: One-click timer

Iedere klant heeft een eigen timer.

### Functionaliteit

- Timer starten
- Timer stoppen
- Wisselen tussen klanten
- Actieve tijd live weergeven
- Automatisch opslaan
- Timerstatus behouden na sluiten van de popover

### Belangrijke technische eis

De timer moet blijven werken wanneer:

- De popover gesloten is.
- De gebruiker naar een andere app wisselt.
- Het scherm wordt vergrendeld.
- De Mac in slaapstand gaat.
- De Mac opnieuw wordt opgestart.

Bij een herstart moet Tikk de laatst opgeslagen timerstatus herstellen.

**Belangrijk:** de timer moet werken op basis van opgeslagen start- en eindtijdstippen, niet op basis van het optellen van seconden in het geheugen.

Hierdoor blijft de tijdregistratie betrouwbaar.

Wanneer de Mac slaapt, telt de verstreken tijd in de MVP standaard mee. Later kan een optie worden toegevoegd om slaaptijd automatisch uit te sluiten.

---

## Feature 3: Daily overview

Gebruikers kunnen zien hoeveel tijd ze vandaag hebben gewerkt.

Bijvoorbeeld:

```text
TODAY

Studio Noord       02:15
Acme Agency        01:30
Eigen werk         00:45

─────────────────────────

Total              04:30
```

De totale tijd wordt automatisch berekend.

Alleen daadwerkelijk geregistreerde tijd wordt meegenomen.

---

## Feature 4: Time overview

Via `View overview` opent een compact, apart macOS-venster.

Dit is het enige grotere venster binnen Tikk.

### Functionaliteit

De gebruiker kan:

- Een dag selecteren.
- Een week bekijken.
- Een maand bekijken.
- Filteren op klant.
- Totale uren per klant zien.
- Individuele tijdregistraties bekijken.

### Voorbeeld

```text
Tikk. / Overview

October 2026

Client            Hours

Studio Noord      32h 45m
Acme Agency       18h 30m
Project Delta     12h 15m
Eigen werk         6h 00m

──────────────────────────

Total             69h 30m
```

Bij het selecteren van een klant worden de afzonderlijke registraties zichtbaar.

Bijvoorbeeld:

```text
Studio Noord

Monday, October 12
09:15 – 11:30       2h 15m
13:00 – 14:45       1h 45m

Tuesday, October 13
10:00 – 12:30       2h 30m
```

---

## Feature 5: Manual adjustments

Gebruikers moeten geregistreerde uren achteraf kunnen aanpassen.

Dit is essentieel voor een bruikbare urenregistratie-app.

### Mogelijkheden

- Starttijd aanpassen.
- Eindtijd aanpassen.
- Een registratie verwijderen.
- Handmatig een registratie toevoegen.
- Een registratie aan een andere klant koppelen.

Wijzigingen worden direct opgeslagen.

De app voorkomt ongeldige registraties, zoals een eindtijd vóór de starttijd.

---

## Feature 6: Export

Gebruikers kunnen hun uren exporteren.

### MVP

CSV-export.

De gebruiker kiest:

- Periode
- Alle klanten of één specifieke klant

### CSV-structuur

```csv
Date,Client,Start,End,Duration,Hours
2026-10-12,Studio Noord,09:15,11:30,02:15,2.25
2026-10-12,Acme Agency,13:00,14:30,01:30,1.50
```

Dit maakt het mogelijk om uren eenvoudig te verwerken in Excel, Numbers of facturatiesoftware.

Een PDF-export kan later worden toegevoegd.

---

# 06. Branding & identiteit

## De naam

# Tikk.

De officiële productnaam is **Tikk**.

In visuele communicatie mag de naam worden weergegeven als:

**tikk.**

De punt maakt de naam herkenbaar en geeft het merk een eigen karakter.

De naam verwijst subtiel naar:

- Het tikken van een klok.
- Een korte klik.
- Het starten van een timer.
- Een klein moment van actie.

De naam is bewust kort, vriendelijk en eenvoudig uit te spreken.

---

## 6.1 Brand personality

Tikk is:

**Friendly. Minimal. Playful. Thoughtful. Quiet.**

Tikk voelt als een klein digitaal hulpmiddel dat met aandacht is ontworpen.

Niet als enterprise-software.

### Wel

- Minimalistisch
- Vriendelijk
- Slim
- Rustig
- Licht speels
- Modern
- Persoonlijk

### Niet

- Corporate
- Druk
- Kinderachtig
- Overdreven kleurrijk
- Complex
- Technisch intimiderend

---

# 07. Tikko — The tiny timekeeper

Naast het woordmerk krijgt Tikk een klein karakter.

Zijn naam is **Tikko**.

Tikko is de mascotte van Tikk en vormt de basis voor de visuele identiteit.

## Het karakter

Tikko is een klein, vriendelijk figuurtje dat tijd bijhoudt.

### Visuele kenmerken

- Compact en rond lichaam.
- Eenvoudig silhouet.
- Twee kleine oogjes.
- Subtiele beentjes of voetjes.
- Geen ingewikkelde details.
- Herkenbaar op zeer kleine afmetingen.

Het figuurtje mag abstract zijn.

Denk aan een kruising tussen een klein klokje, een digitaal huisdiertje en een minimalistische Mac-mascotte.

### Belangrijk

Tikko moet herkenbaar blijven als monochroom icoon van ongeveer 16–18 pixels in de menubalk.

Daarom moet het silhouet belangrijker zijn dan de details.

---

## 7.1 De verschillende states van Tikko

Tikko kan subtiel reageren op de status van de timer.

### Idle

Tikko staat stil.

Neutrale, ontspannen uitstraling.

Betekenis: er wordt geen tijd bijgehouden.

### Tracking

Tikko is actief.

Een subtiel veranderend detail maakt duidelijk dat de timer loopt.

Bijvoorbeeld:

- Een klein stipje.
- Een veranderend oogje.
- Een minimalistische animatie in de popover.

### Finished

Wanneer een timer wordt gestopt, kan Tikko heel kort een tevreden reactie tonen.

Bijvoorbeeld een subtiele knipoog.

### Technische randvoorwaarde

De menubalkanimatie mag geen onnodige CPU-belasting veroorzaken.

Animaties moeten optioneel zijn en rekening houden met de toegankelijkheidsinstelling *Reduce Motion*.

---

# 08. Visual design

## Design direction

Tikk moet voelen als een premium, native macOS-utility.

Inspiratie:

- Kleine onafhankelijke Mac-apps.
- Minimalistische productiviteitssoftware.
- Zorgvuldig ontworpen systeeminterfaces.
- Subtiele, vriendelijke micro-interacties.

### Kleuren

Voorgestelde basiskleuren:

**Warm Off-White**  
`#F8F7F4`

**Soft Black**  
`#242424`

**Tikk Orange**  
`#FF8A4C`

**Muted Gray**  
`#969696`

**Soft Green**  
`#91B89A`

Oranje is de primaire accentkleur.

Deze kleur wordt gebruikt voor actieve timers, kleine accenten en de merkidentiteit.

In de macOS-menubalk gebruikt Tikk waar nodig monochrome systeemiconen, zodat het icoon goed werkt in zowel light mode als dark mode.

### Typografie

Gebruik zoveel mogelijk de native macOS-systeemtypografie: SF Pro.

Voor het woordmerk kan later een eigen afgeronde typografische stijl worden ontwikkeld.

### Interface

- Compacte afmetingen.
- Royale witruimte waar mogelijk.
- Subtiele afgeronde hoeken.
- Geen overbodige borders.
- Duidelijke visuele hiërarchie.
- Kleine, functionele animaties.
- Ondersteuning voor light en dark mode.

De interface moet aanvoelen alsof Tikk onderdeel is van macOS.

---

# 09. Technische architectuur

## Platform

**macOS — native application**

Tikk wordt in eerste instantie uitsluitend voor macOS ontwikkeld.

Er is geen webapp, mobiele app of Windows-versie nodig voor de MVP.

## Aanbevolen stack

**Language:** Swift  
**UI framework:** SwiftUI  
**Menu bar:** MenuBarExtra  
**Persistence:** SwiftData of SQLite  
**Architecture:** MVVM of vergelijkbare lichte architectuur  
**Minimum macOS version:** macOS 14 Sonoma

### Waarom native?

Een native Swift-app biedt:

- Snelle opstarttijd.
- Laag geheugengebruik.
- Goede integratie met de macOS-menubalk.
- Native systeemgedrag.
- Minder afhankelijkheden.
- Een kleine applicatie.
- Goede ondersteuning voor systeemnotificaties en toegankelijkheid.

Gebruik geen Electron voor de MVP.

Tikk moet licht en snel zijn.

---

# 10. Applicatiestructuur

De applicatie bestaat uit vier hoofdonderdelen.

## 10.1 Menu Bar Controller

Verantwoordelijk voor:

- Het menubalkicoon.
- De popover.
- Het tonen van actieve tijd.
- De lijst met klanten.
- Start- en stopacties.

## 10.2 Timer Engine

Verantwoordelijk voor:

- Timers starten.
- Timers stoppen.
- Wisselen tussen klanten.
- Tijd berekenen.
- Actieve sessies herstellen.
- Voorkomen dat meerdere timers tegelijk lopen.

De timer-engine is onafhankelijk van de interface.

## 10.3 Local Data Store

Verantwoordelijk voor:

- Klanten opslaan.
- Tijdregistraties opslaan.
- Actieve sessie bewaren.
- Instellingen bewaren.
- Gegevens ophalen voor overzichten.

## 10.4 Overview Window

Verantwoordelijk voor:

- Dagoverzicht.
- Weekoverzicht.
- Maandoverzicht.
- Filters.
- Handmatige aanpassingen.
- CSV-export.

---

# 11. Datamodel

## Client

```swift
Client {
    id: UUID
    name: String
    color: String
    hourlyRate: Decimal?
    isArchived: Bool
    createdAt: Date
}
```

## TimeEntry

```swift
TimeEntry {
    id: UUID
    clientId: UUID
    startTime: Date
    endTime: Date?
    createdAt: Date
    updatedAt: Date
}
```

Een `endTime` van `nil` betekent dat een registratie nog actief is.

## Settings

```swift
AppSettings {
    launchAtLogin: Bool
    showTimerInMenuBar: Bool
    showSeconds: Bool
    animationsEnabled: Bool
    preferredAppearance: String
}
```

### Dataregels

- Er mag maximaal één actieve registratie bestaan.
- Elke registratie is gekoppeld aan een klant.
- Registraties worden direct lokaal opgeslagen.
- Tijdsberekeningen gebruiken absolute tijdstippen.
- Duur wordt afgeleid uit start- en eindtijd.
- Overzichten houden rekening met de lokale tijdzone.
- Registraties die over middernacht lopen, worden correct over de betreffende dagen verdeeld.

---

# 12. Settings

De instellingen blijven bewust beperkt.

### General

**Launch at login**  
Tikk automatisch starten bij het inloggen.

**Show timer in menu bar**  
Actieve tijd naast het icoontje tonen.

**Show seconds**  
Seconden wel of niet weergeven.

### Appearance

**Theme**
- System
- Light
- Dark

**Animations**
- On
- Off

### Data

**Export data**

**Data location**

**Backup data**

### About

Tikk-versie en korte productinformatie.

---

# 13. Onboarding

De onboarding moet extreem kort zijn.

Bij de eerste keer openen verschijnt een compacte welkomstinterface.

### Screen 1

**Meet Tikk.**

Your tiny timekeeper.

Track your hours with a single click, right from your menu bar.

Button: **Get started**

### Screen 2

**Who are you working for?**

Add your first client.

Input: `Client name`

Button: **Add client**

Na het toevoegen verschijnt de klant direct in de menubalkpopover.

De gebruiker kan meteen beginnen.

Geen accountregistratie.

Geen e-mailadres.

Geen uitgebreide configuratie.

---

# 14. Wat bouwen we bewust niet?

Om Tikk klein en gefocust te houden, vallen de volgende onderdelen buiten de MVP:

- Facturen genereren.
- Projectmanagement.
- Teamaccounts.
- Samenwerken met collega's.
- Cloudsync.
- Mobiele apps.
- Integraties met boekhoudsoftware.
- AI-functionaliteiten.
- Automatische screenshots.
- Activiteitenmonitoring.
- Uitgebreide rapportages.
- Abonnementen of betalingen.

Deze onderdelen mogen de basisarchitectuur niet onnodig ingewikkeld maken.

**Tikk is een time tracker. Geen bedrijfsplatform.**

---

# 15. Kwaliteit en betrouwbaarheid

De belangrijkste kwaliteitseis is dat gebruikers op hun urenregistratie kunnen vertrouwen.

### Acceptatiecriteria

**Timer**
- Start onmiddellijk na het selecteren van een klant.
- Stopt onmiddellijk na een tweede klik.
- Wisselt zonder dubbele registraties tussen klanten.
- Blijft doorlopen wanneer de popover sluit.
- Herstelt correct na het opnieuw openen van de app.

**Data**
- Registraties worden persistent opgeslagen.
- Gegevens verdwijnen niet bij een onverwachte afsluiting.
- Uren worden correct berekend.
- Export bevat dezelfde uren als het overzicht.

**Interface**
- Menubalkicoon werkt in light en dark mode.
- De app is bruikbaar zonder groot venster.
- De interface blijft responsief.
- Klanten kunnen met minimale interactie worden geselecteerd.

**Performance**
- Laag CPU-gebruik wanneer Tikk op de achtergrond draait.
- Geen onnodige polling of zware processen.
- Geen netwerkverbinding nodig.
- Geen merkbare vertraging bij het openen van de popover.

---

# 16. Build roadmap

> **v1.1:** Phase 1 en Phase 2 worden samen als één fase gebouwd, in de volgorde van Phase 1 en daarna Phase 2. Zie sectie 00.

## Phase 1 — Functional foundation

**Doel:** een werkende menubalktimer.

Bouw:

1. Native macOS-project.
2. Menubalkicoon.
3. Compacte popover.
4. Klanten toevoegen.
5. Klantenlijst.
6. Timer starten en stoppen.
7. Automatisch wisselen tussen klanten.
8. Lokale opslag.
9. Actieve timer herstellen.

**Resultaat:** Tikk kan betrouwbaar uren bijhouden voor meerdere klanten.

---

## Phase 2 — Overview & editing

**Doel:** geregistreerde uren inzichtelijk en bruikbaar maken.

Bouw:

1. Dagoverzicht.
2. Weekoverzicht.
3. Maandoverzicht.
4. Klantfilters.
5. Individuele tijdregistraties.
6. Handmatig toevoegen en aanpassen.
7. CSV-export.

**Resultaat:** Tikk is bruikbaar voor dagelijkse urenregistratie en maandelijkse facturatievoorbereiding.

---

## Phase 3 — Polish & branding

**Doel:** Tikk laten voelen als een afgewerkt product.

Bouw:

1. Definitief Tikk-logo.
2. Tikko-mascotte.
3. Aangepast menubalkicoon.
4. Light- en dark-mode-afwerking.
5. Subtiele micro-interacties.
6. Onboarding.
7. Settings.
8. Launch at login.
9. Keyboard accessibility.
10. Foutafhandeling en edge cases.

**Resultaat:** een kleine, verzorgde macOS-app die prettig is om dagelijks te gebruiken.

---

# 17. Future ideas

Mogelijke uitbreidingen na de MVP.

> **v1.1:** Tiny notes, de sneltoets en afwezigheidsdetectie bij slaapstand zijn naar de MVP verplaatst (sectie 00). Volledige idle detection tijdens actief gebruik blijft hieronder staan.

### Agenda-koppeling

Een afspraak uit Apple Agenda omzetten in een registratie.

### Shortcuts en AppleScript

Ondersteuning voor Apple Opdrachten om timers te automatiseren.

### Idle detection

Tikk merkt op wanneer de gebruiker langere tijd niet actief is.

De gebruiker kan vervolgens kiezen of die tijd moet meetellen.

### Weekly summary

Een subtiele samenvatting aan het einde van de week.

### PDF timesheet

Een nette urenstaat genereren om naar een klant te sturen.

### Tikk reminders

Een vriendelijke herinnering wanneer er al langere tijd geen timer is gestart.

Geen agressieve notificaties.

### Tiny achievements

Kleine, speelse interacties met Tikko.

Bijvoorbeeld wanneer de gebruiker een werkweek afrondt.

Deze elementen mogen nooit de kernfunctionaliteit verstoren.

---

# 18. Definitie van succes

Tikk is geslaagd wanneer een freelancer de app kan installeren, een klant kan toevoegen en binnen enkele seconden zijn eerste timer kan starten.

De gebruiker hoeft niet na te denken over hoe de applicatie werkt.

Na een maand gebruik moet de gebruiker eenvoudig kunnen zien:

- Voor welke klanten is gewerkt.
- Op welke dagen is gewerkt.
- Hoeveel uur er is gewerkt.
- Welke uren gefactureerd kunnen worden.

En dat alles zonder dat urenregistratie zelf veel tijd kost.

---

# 19. De kern in één zin

**Tikk is een kleine, vriendelijke macOS-menubalkapp waarmee freelancers met één klik hun uren per klant bijhouden.**

Geen gedoe.

Geen afleiding.

Gewoon:

**Click. Work. Tikk.**

---

# 20. Development instruction

Build Tikk as a lightweight, native macOS menu bar application using Swift and SwiftUI.

Prioritize simplicity, performance, reliability, and native macOS behavior.

The core interaction must allow users to start, stop, and switch between client timers with a single click.

Use local persistence, maintain accurate time records, and provide a clean overview with CSV export.

Keep the application focused and avoid unnecessary features, dependencies, and complexity.

The visual identity should be minimal, friendly, and slightly playful, centered around the Tikk brand and its small mascot, Tikko.

**The final product should feel like a tiny, beautifully crafted Mac utility — not a traditional time-tracking platform.**