import Foundation

// MARK: - MopsAblage (Stufe 2)
//
// Der sichtbare „iMOPS"-Ordner in iCloud Drive → Finder-Seitenleiste am Mac +
// Dateien-App auf iPad/iPhone + Sync. Damit hat ein Nutzer EINEN offensichtlichen
// Ablageort für Baustellen-Dokumente (aus Mail/Download/anderem User), ohne sich
// selbst einen Ordner anlegen zu müssen — der DAU-Punkt.
//
// Struktur:
//   iMOPS/
//     _Firma/                (app-weit: Stammdaten, Firmeneinstellungen)
//     Baustellen/
//       <Baustelle>/         (Stufe 3: mit Dokument-Fächern)
//
// ALLES nil-sicher: ist kein iCloud angemeldet, gibt es keinen Container → die App
// läuft völlig normal weiter (der Ordner erscheint dann eben nicht). Nie ein Crash,
// nie ein Block: `url(forUbiquityContainerIdentifier:)` kann blockieren und läuft
// deshalb IMMER im Hintergrund, nie auf dem Main-Thread.

enum MopsAblage {

    static let containerID = "iCloud.io.imops.iMOPS-Construction-Grid-Baustellen-Management-"

    /// Die Dokument-Fächer je Baustelle (Stufe 3).
    static let baustellenFaecher = ["Architektur", "Vermessung", "Statik",
                                    "Gutachten", "Genehmigung", "Sonstiges"]

    /// Sichtbarer Wurzel-Ordner (…/Documents im Ubiquity-Container). nil = iCloud nicht da.
    static func wurzel() -> URL? {
        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: containerID) else {
            return nil
        }
        return container.appendingPathComponent("Documents", isDirectory: true)
    }

    /// Grundstruktur anlegen (idempotent): _Firma + Baustellen. Gibt Erfolg zurück.
    @discardableResult
    static func stelleGrundstrukturSicher() -> Bool {
        guard let wurzel = wurzel() else { return false }
        let fm = FileManager.default
        for ordner in ["_Firma", "Baustellen"] {
            try? fm.createDirectory(at: wurzel.appendingPathComponent(ordner, isDirectory: true),
                                    withIntermediateDirectories: true)
        }
        return true
    }

    /// Ordner für eine Baustelle inkl. Dokument-Fächer (idempotent). nil = iCloud nicht da.
    @discardableResult
    static func ordnerFuerBaustelle(_ name: String) -> URL? {
        guard let wurzel = wurzel() else { return nil }
        let sicher = name.replacingOccurrences(of: "/", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sicher.isEmpty else { return nil }
        let baustelle = wurzel
            .appendingPathComponent("Baustellen", isDirectory: true)
            .appendingPathComponent(sicher, isDirectory: true)
        let fm = FileManager.default
        for fach in baustellenFaecher {
            try? fm.createDirectory(at: baustelle.appendingPathComponent(fach, isDirectory: true),
                                    withIntermediateDirectories: true)
        }
        return baustelle
    }

    /// Beim App-Start im Hintergrund die Grundstruktur sicherstellen (Main-Thread-Falle vermeiden).
    static func imHintergrundVorbereiten() {
        DispatchQueue.global(qos: .utility).async {
            stelleGrundstrukturSicher()
        }
    }
}
