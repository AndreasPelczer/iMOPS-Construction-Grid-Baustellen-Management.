//
//  ModellVersionierungTests.swift
//  Fundament: Core-Data-Modellversionierung.
//
//  Lightweight Migration kann Core Data nur *inferieren*, wenn das alte Modell
//  noch als eigene Version im Bundle liegt. Bei nur einer Version gibt es kein
//  „von-Modell“ — auf einem Gerät mit Altdaten scheitert dann das erste Öffnen
//  nach dem Update. Im Simulator fällt das nie auf, weil dort neu installiert
//  wird. Diese Tests halten den Versionsweg fest.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct ModellVersionierungTests {

    private var momdURL: URL {
        get throws {
            try #require(Bundle.main.url(forResource: "test25B", withExtension: "momd"))
        }
    }

    private var versionInfo: [String: Any] {
        get throws {
            let url = try momdURL.appendingPathComponent("VersionInfo.plist")
            let daten = try Data(contentsOf: url)
            let plist = try PropertyListSerialization.propertyList(from: daten, format: nil)
            return try #require(plist as? [String: Any])
        }
    }

    // MARK: - Struktur

    /// Es muss mehr als eine Version geben, sonst hat eine künftige Migration
    /// kein Modell, gegen das sie inferieren könnte.
    @Test func momdEnthaeltMehrAlsEineVersion() throws {
        let hashes = try #require(
            versionInfo["NSManagedObjectModel_VersionHashes"] as? [String: Any])
        // Ein Literal, keine Konkatenation: der zweite #expect-Parameter ist ein
        // `Comment`, und ein zusammengesetzter String konvertiert nicht dorthin.
        #expect(hashes.count >= 2, "Nur \(hashes.count) Version(en) im .momd — ohne von-Modell kann Lightweight Migration nicht inferieren.")
    }

    /// Der Kern: lädt `Persistence.swift` (per .momd-URL) wirklich die
    /// **aktuelle** Version — und nicht irgendeine? Solange V1 und V2 gleich
    /// sind, ist das nicht zu merken; sobald V2 abweicht, hängt alles daran.
    @Test func geladenesModellIstDieAktuelleVersion() throws {
        let info = try versionInfo
        let aktuell = try #require(
            info["NSManagedObjectModel_CurrentVersionName"] as? String)
        let alleHashes = try #require(
            info["NSManagedObjectModel_VersionHashes"] as? [String: [String: Data]])
        let erwartet = try #require(alleHashes[aktuell])

        let geladen = try #require(NSManagedObjectModel(contentsOf: try momdURL))
        #expect(geladen.entityVersionHashesByName == erwartet,
                "Geladen wurde nicht die als current markierte Version „\(aktuell)“.")
    }

    /// Nimmt einer Modellkopie den Anspruch auf die App-Klassen.
    ///
    /// `Persistence.swift` lädt das Modell absichtlich **genau einmal**: hängen zwei
    /// Modelle mit demselben `managedObjectClassName` an Coordinators, gibt es doppelte
    /// `NSEntityDescription`s für dieselbe Subklasse — und Core Data greift daneben.
    /// Swift Testing fährt Suites **parallel**, dieser Test lief also gegen die
    /// laufenden Core-Data-Tests der anderen Suites und hat sie reihenweise umgeworfen
    /// (wechselnde Opfer, je nach Zeitpunkt).
    ///
    /// Für die Migrationsprüfung ist die Klassenzuordnung ohne Bedeutung — der
    /// Versions-Hash hängt am Schema, nicht am Klassennamen. Also alles auf das
    /// generische `NSManagedObject` umbiegen; zugegriffen wird ohnehin per `setValue`.
    private func ohneKlassenanspruch(_ modell: NSManagedObjectModel) throws -> NSManagedObjectModel {
        let kopie = try #require(modell.copy() as? NSManagedObjectModel)
        let generisch = NSStringFromClass(NSManagedObject.self)
        for entity in kopie.entities {
            entity.managedObjectClassName = generisch
        }
        return kopie
    }

    // MARK: - Migration V1 -> V2

    /// Der eigentliche Nachweis — und er kommt ohne Store aus.
    ///
    /// `NSMappingModel.inferredMappingModel` arbeitet **rein auf Modellebene**: kein
    /// Coordinator, kein `NSPersistentContainer`, keine Objekte. Damit fällt genau das
    /// weg, was den früheren Alt-Store-Test die halbe Suite hat umwerfen lassen
    /// (siehe unten). Wirft die Methode, ist die Migration NICHT inferierbar — dann
    /// scheitert auf einem Gerät mit Altdaten das erste Öffnen nach dem Update.
    @Test func migrationVonDerAltenZurAktuellenVersionIstInferierbar() throws {
        let momd = try momdURL
        let info = try versionInfo
        let aktuell = try #require(info["NSManagedObjectModel_CurrentVersionName"] as? String)
        let alleHashes = try #require(info["NSManagedObjectModel_VersionHashes"] as? [String: Any])
        let altName = try #require(alleHashes.keys.first { $0 != aktuell })

        let quelle = try #require(
            NSManagedObjectModel(contentsOf: momd.appendingPathComponent("\(altName).mom")))
        let ziel = try #require(
            NSManagedObjectModel(contentsOf: momd.appendingPathComponent("\(aktuell).mom")))

        // Wenn beide gleich wären, prüfte der Test nichts.
        #expect(quelle.entityVersionHashesByName != ziel.entityVersionHashesByName,
                "Alte und aktuelle Version sind identisch — hier ist nichts zu migrieren.")

        let mapping = try NSMappingModel.inferredMappingModel(
            forSourceModel: quelle, destinationModel: ziel)
        #expect(mapping.entityMappings.isEmpty == false)
    }

    /// Schutz gegen genau den Fehler, der beim Aufsetzen der Versionierung passiert ist:
    /// eine Modelländerung landet in der ALTEN Version, current bleibt ohne sie. Build
    /// und Merge blieben dabei grün, die App lädt aber ein Modell ohne die Relationen.
    @Test func aktuelleVersionTraegtDieKausalketteAusPR140() throws {
        let geladen = try #require(NSManagedObjectModel(contentsOf: try momdURL))
        let voraussetzung = try #require(geladen.entitiesByName["Voraussetzung"])
        let auftrag = try #require(geladen.entitiesByName["Auftrag"])

        #expect(voraussetzung.relationshipsByName["quelle"] != nil)
        #expect(voraussetzung.relationshipsByName["auftrag"] != nil)
        #expect(auftrag.relationshipsByName["istVoraussetzungFuer"] != nil)
        #expect(auftrag.relationshipsByName["voraussetzungen"] != nil)
    }

    // MARK: - Was hier NICHT getestet wird, und warum

    // Ein Test, der einen echten Alt-Store anlegt (SQLite mit der V1-Version) und
    // ihn mit dem aktuellen Modell öffnet, stand hier — und wurde wieder entfernt.
    //
    // Er lief isoliert grün, hat aber in der vollen Suite reihenweise fremde Tests
    // umgeworfen, mit wechselnden Opfern. Der Crash-Report zeigt die Ursache:
    //
    //     -[NSManagedObject initWithEntity:insertIntoManagedObjectContext:]
    //     Event.init(entity:insertInto:)
    //
    // Genau das, wovor `Persistence.swift` warnt: das Datenmodell wird dort bewusst
    // GENAU EINMAL geladen, weil zwei Modelle im selben Prozess doppelte
    // `NSEntityDescription`s für dieselbe Subklasse ergeben. Swift Testing fährt
    // Suites parallel — der Alt-Store-Test lief also gegen die Core-Data-Tests der
    // anderen Suites. Die Entities der Kopien auf `NSManagedObject` umzubiegen hat
    // NICHT gereicht; sauber ginge es nur in einem eigenen Testprozess.
    //
    // Deshalb steht die Migration von einem gewachsenen Altbestand als
    // **manuelle Prüfung** aus: App mit Daten installieren, Update einspielen,
    // prüfen dass sie ohne Reset startet. Siehe docs/HANDOFF-AKTUELL.md.
    // Sie ist NICHT nachgewiesen — die zwei Tests oben prüfen nur die Struktur.
}
