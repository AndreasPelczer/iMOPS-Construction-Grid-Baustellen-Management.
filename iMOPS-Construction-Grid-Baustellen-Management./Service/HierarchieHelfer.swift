import Foundation
import CoreData

// Welle 9 — Hierarchie-Helfer.
// Stellt sicher, dass eine Baustelle (Event) mindestens ein Gebäude + ein Geschoss hat,
// ordnet alle noch nicht zugeordneten LV-Positionen dem Default-Geschoss zu und gibt
// dieses zurück. Das ist die laufende Fassung der Bootstrap-Logik aus HierarchieMigration:
// die Migration lief nur EINMAL (UserDefaults-Flag) — neue Baustellen und alle nach der
// Migration importierten/angelegten Positionen bekämen sonst geschoss == nil.
//
// Idempotent: legt nur an, was fehlt, und ordnet nur nil-Positionen zu.
enum HierarchieHelfer {

    static let defaultGebaeudeName = "Hauptgebäude"
    static let defaultGeschossName = "Allgemein / EG"

    /// Das Default-(erste)-Geschoss der Baustelle, sortiert nach `reihenfolge`. nil, wenn
    /// die Baustelle noch keine Hierarchie hat.
    static func defaultGeschoss(for event: Event) -> Geschoss? {
        let gebaeude = (event.gebaeude as? Set<Gebaeude>)?.sorted { $0.reihenfolge < $1.reihenfolge } ?? []
        for g in gebaeude {
            if let geschoss = (g.geschosse as? Set<Geschoss>)?
                .sorted(by: { $0.reihenfolge < $1.reihenfolge }).first {
                return geschoss
            }
        }
        return nil
    }

    /// Sichert Gebäude + Geschoss (legt bei Bedarf an), hängt alle `geschoss == nil`-
    /// Positionen der Baustelle ein und gibt das Default-Geschoss zurück.
    /// `geaendert` sagt, ob etwas verändert wurde (damit der Aufrufer gezielt speichern kann).
    @discardableResult
    static func sichereDefaultGeschoss(for event: Event,
                                       in context: NSManagedObjectContext) -> (geschoss: Geschoss, geaendert: Bool) {
        var geaendert = false
        var geschoss = defaultGeschoss(for: event)

        if geschoss == nil {
            // Gebäude nehmen, falls schon eins existiert, sonst „Hauptgebäude" anlegen.
            let gebaeude: Gebaeude
            if let vorhanden = (event.gebaeude as? Set<Gebaeude>)?
                .sorted(by: { $0.reihenfolge < $1.reihenfolge }).first {
                gebaeude = vorhanden
            } else {
                let g = Gebaeude(context: context)
                g.id = UUID(); g.name = defaultGebaeudeName; g.reihenfolge = 0; g.event = event
                gebaeude = g
            }
            let neu = Geschoss(context: context)
            neu.id = UUID(); neu.name = defaultGeschossName; neu.reihenfolge = 0; neu.gebaeude = gebaeude
            geschoss = neu
            geaendert = true
        }

        if let ziel = geschoss, let positionen = event.lvPositionen as? Set<LVPosition> {
            for pos in positionen where pos.geschoss == nil {
                pos.geschoss = ziel
                geaendert = true
            }
        }

        // Voraussetzungs-Katalog (5 manuelle) für alle Geschosse der Baustelle sichern (idempotent).
        for g in alleGeschosse(for: event) {
            if sichereVoraussetzungen(for: g, in: context) { geaendert = true }
        }

        // `geschoss` ist hier garantiert gesetzt.
        return (geschoss!, geaendert)
    }

    // MARK: - Abfragen (Stufe B: Picker + Verwaltung)

    static func alleGebaeude(for event: Event) -> [Gebaeude] {
        (event.gebaeude as? Set<Gebaeude>)?.sorted(by: { $0.reihenfolge < $1.reihenfolge }) ?? []
    }

    static func geschosse(of gebaeude: Gebaeude) -> [Geschoss] {
        (gebaeude.geschosse as? Set<Geschoss>)?.sorted(by: { $0.reihenfolge < $1.reihenfolge }) ?? []
    }

    /// Alle Geschosse der Baustelle, nach Gebäude- und Geschoss-Reihenfolge sortiert.
    static func alleGeschosse(for event: Event) -> [Geschoss] {
        alleGebaeude(for: event).flatMap { geschosse(of: $0) }
    }

    // MARK: - Anlegen (Stufe B: Verwaltung)

    @discardableResult
    static func neuesGebaeude(name: String, for event: Event,
                              in context: NSManagedObjectContext) -> Gebaeude {
        let g = Gebaeude(context: context)
        g.id = UUID()
        g.name = name
        g.reihenfolge = Int16(alleGebaeude(for: event).count)
        g.event = event
        return g
    }

    @discardableResult
    static func neuesGeschoss(name: String, in gebaeude: Gebaeude,
                              context: NSManagedObjectContext) -> Geschoss {
        let s = Geschoss(context: context)
        s.id = UUID()
        s.name = name
        s.reihenfolge = Int16(geschosse(of: gebaeude).count)
        s.gebaeude = gebaeude
        sichereVoraussetzungen(for: s, in: context)   // Default-Katalog gleich mitgeben
        return s
    }

    // MARK: - Voraussetzungs-Katalog (Stufe C, §3)

    /// Manuelle Default-Voraussetzungen je Geschoss (Fertigmeldung / Abrechnungsreife).
    /// Reihenfolge = Index. Freigegeben von Andreas 2026-07-04.
    static let manuelleDefaultVoraussetzungen: [String] = [
        "Alle Leistungen des Geschosses erfasst",
        "Aufmaß gemeinsam mit AN geprüft",
        "Keine offenen Mängel im Geschoss",
        "Fotodoku / Bautagesbericht vorhanden",
        "Nachträge geklärt",
    ]

    /// Legt die 5 manuellen Voraussetzungen an, falls das Geschoss noch keine hat.
    /// Idempotent (keine Doubletten). Gibt zurück, ob etwas angelegt wurde.
    @discardableResult
    static func sichereVoraussetzungen(for geschoss: Geschoss,
                                       in context: NSManagedObjectContext) -> Bool {
        guard (geschoss.voraussetzungen?.count ?? 0) == 0 else { return false }
        for (i, name) in manuelleDefaultVoraussetzungen.enumerated() {
            let v = Voraussetzung(context: context)
            v.id = UUID()
            v.name = name
            v.typ = VoraussetzungsTyp.manuell.rawValue
            v.erfuellt = false
            v.reihenfolge = Int16(i)
            v.geschoss = geschoss
        }
        return true
    }
}
