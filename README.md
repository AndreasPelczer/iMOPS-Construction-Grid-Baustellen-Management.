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

## Backend (Mops-API)

Die iOS-App spricht mit einem lokalen LLM-Backend (Mops + Prof + RAG):

- **Repo:** [AndreasPelczer/mops-api](https://github.com/AndreasPelczer/mops-api)
- **Host:** 192.168.2.42:8080 (Mops-Box, Ubuntu, llama3.2:3b CPU-only)
- **Endpoints:** `/chat`, `/classify`, `/health`, `/admin-ui`
- **Routing:** `/prof ` Prefix routet an Claude Sonnet 4.5

Server-Code lebt in einem eigenen Repo, damit iOS- und Backend-Entwicklung
unabhaengig versioniert werden koennen.

## Features (MVP)

- Events/Baustellen verwalten
- Auftraege (Jobs) mit Checklisten und SOP-Templates
- Mitarbeiter-/Crew-Planung
- Rollen-System (Mitarbeiter, Disponent, Leitung)
