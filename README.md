# iMOPS Construction Grid - Baustellen-Management

SwiftUI iOS-App fuer Baustellen- und Auftragsmanagement.

## Projektstruktur

```
App/                  - App Entry Point + Session
Models/               - Core Data Entities (Event, Auftrag, Employee, etc.)
Views/                - SwiftUI Views
ViewModels/           - MVVM ViewModels
Service/              - Persistence, Seeder, Templates
```

## Setup (Xcode)

1. Repo klonen
2. In Xcode: File > New Project > iOS App (SwiftUI, Core Data)
3. Swift-Dateien aus diesem Repo ins Xcode-Projekt ziehen
4. Core Data Model `test25B.xcdatamodeld` einbinden
5. Build & Run

## Architektur

- **SwiftUI** + **Core Data** (Offline-First)
- **MVVM** Pattern
- Keine externen Abhaengigkeiten (nur Apple Frameworks)

## Features (MVP)

- Events/Baustellen verwalten
- Auftraege (Jobs) mit Checklisten und SOP-Templates
- Mitarbeiter-/Crew-Planung
- Rollen-System (Mitarbeiter, Disponent, Leitung)
