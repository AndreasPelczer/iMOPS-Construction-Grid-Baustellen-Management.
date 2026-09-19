import Foundation
import CoreData

// MARK: - PreisAnhaengeService
//
// Schritt 4: der Kupplungs-Klick. Die Preise liegen in den Stammdaten (KalkMaterial),
// hängen aber noch nicht an den LV-Positionen — darum zeigt die Position nur den Lohn
// (z. B. Betonstahl 0,71 €, das Material 1,20 € fehlt). Dieser Service SCHLÄGT pro
// Position die passende Stammdaten-Material vor (Namens-Treffer); der Mensch bestätigt,
// dann wird eine Material-Zeile angehängt und der EP springt auf Lohn + Material.
//
// TAO: Vorschlag statt Erfindung. Der Mops rät den Treffer, der Mensch bestätigt — kein
// automatisches Andocken einer womöglich falschen Zahl. Bestätigen kann auch ein Nicht-
// Baumann (Beton-Position → Beton-Material ist offensichtlich).

struct PreisAnhaengeService {

    static let shared = PreisAnhaengeService()

    /// Ein Vorschlag: welche Stammdaten-Material passt zu dieser Position?
    struct Vorschlag {
        let material: KalkMaterial
        let score: Double          // 0…1, Anteil getroffener Namens-Bestandteile
        let einheitPasst: Bool     // Material-Einheit == Positions-Einheit (Faktor 1 sauber)
    }

    /// Bester Material-Vorschlag für eine Position (nil = kein sicherer Treffer).
    /// Schwelle 0,6 — darunter lieber „kein Vorschlag" als ein falscher.
    func besterVorschlag(fuer position: LVPosition,
                         aus materialien: [KalkMaterial]) -> Vorschlag? {
        let p = normalisiere(position.bezeichnung ?? "")
        guard !p.isEmpty else { return nil }

        var bester: Vorschlag?
        for m in materialien {
            let tokens = normalisiere(m.name ?? "").split(separator: " ").map(String.init)
            guard !tokens.isEmpty else { continue }
            let treffer = tokens.filter { p.contains($0) }.count
            let score = Double(treffer) / Double(tokens.count)
            guard score >= 0.6 else { continue }
            let besser = score > (bester?.score ?? 0)
                || (score == bester?.score && (m.name?.count ?? 0) > (bester?.material.name?.count ?? 0))
            if besser {
                let passt = (m.einheit ?? "").lowercased() == (position.einheit ?? "").lowercased()
                bester = Vorschlag(material: m, score: score, einheitPasst: passt)
            }
        }
        return bester
    }

    /// Hängt eine Stammdaten-Material als Kalkulations-Zeile an die Position.
    /// Idempotent: dieselbe Material (Name) wird nicht doppelt angehängt.
    /// Menge je Einheit = 1 (Position und Material in derselben Einheit, z. B. m³ Beton je
    /// m³ Beton, kg Stahl je kg). Verschnitt 0 — bewusst nicht geraten, später anpassbar.
    /// Gibt true zurück, wenn wirklich angehängt wurde.
    @discardableResult
    func haengeAn(material: KalkMaterial, an position: LVPosition,
                  in ctx: NSManagedObjectContext) -> Bool {
        let name = material.name ?? ""
        let schonDran = position.materialArray.contains {
            ($0.materialName ?? "").lowercased() == name.lowercased()
        }
        guard !schonDran else { return false }

        let pm = PositionMaterial(context: ctx)
        pm.id = UUID()
        pm.materialName = name
        pm.einheit = material.einheit
        pm.mengeProEinheit = 1.0
        pm.einzelpreis = material.preisProEinheit
        pm.verschnittProzent = 0
        pm.quelle = "eigen"          // vom Menschen bestätigt → dein Wert (grün)
        pm.position = position
        return true
    }

    // MARK: - Helfer

    /// Kleinbuchstaben, alles Nicht-Alphanumerische zu Leerzeichen, Mehrfach-Leerzeichen weg.
    /// „Beton C25/30" und „…C25-30 d=16" werden vergleichbar (Slash/Bindestrich → Leer).
    private func normalisiere(_ s: String) -> String {
        let scalars = s.lowercased().unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0) ? Character($0) : " "
        }
        return String(scalars).split(separator: " ").joined(separator: " ")
    }
}
