import Foundation
import CoreData

// MARK: - Firmenprofil
// Umschalter „echte Firma (Goldschmitt)" ↔ „Mops (neutral)". Bestimmt, mit WELCHEN
// Lohnsätzen die Kalkulation rechnet — Goldschmitts echte Sätze (ZG1 = 74 €/h) oder die
// neutralen Bau-Tarif-Defaults. So kann man an denselben Positionen sofort vergleichen,
// an welcher Schraube gedreht wird.
//
// Mops-Modus = DSGVO-sicherer Demo-Modus: keine Goldschmitt-Zahl ist mehr im Spiel.
//
// Kern-Trick: Rolle + Stunden stehen getrennt auf der Position (`PositionLohn`), der Satz
// wird hier je Profil bestimmt — die Vergleichszahl entsteht aus denselben Stunden.
enum Firmenprofil: String, CaseIterable, Sendable {
    case goldschmitt   // echte Firma (Raphaels Kalkulationswerte)
    case mops          // neutral (öffentliche Bau-Tarif-Orientierung, Demo)

    /// UserDefaults-Schlüssel (auch für @AppStorage in den Settings).
    static let defaultsKey = "firmenprofil_aktiv"

    /// Das aktuell aktive Profil (Default: Goldschmitt = der echte Betrieb).
    static var aktiv: Firmenprofil {
        Firmenprofil(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .goldschmitt
    }

    static func setzeAktiv(_ p: Firmenprofil) {
        UserDefaults.standard.set(p.rawValue, forKey: defaultsKey)
    }

    var anzeige: String {
        switch self {
        case .goldschmitt: return "Goldschmitt (echt)"
        case .mops:        return "Mops (neutral)"
        }
    }

    // MARK: - Tarifsätze je Profil

    // Neutrale Bau-Tarif-Orientierung (Mops) — dieselben Defaults wie in bruttoEK.
    private func neutral(_ g: LeistungskatalogService.Tarifgruppe) -> Double {
        switch g {
        case .helfer:       return 18.50 * 1.55   // ~28,68
        case .facharbeiter: return 28.50 * 1.65   // ~47,03
        case .maschinist:   return 30.00 * 1.65   // ~49,50
        }
    }

    /// Der Brutto-EK-Satz für eine Tarifgruppe im aktiven/gewählten Profil.
    /// Goldschmitt liest seine echten Sätze aus den Stammdaten (`Lohnsatz`), sonst neutral.
    func satz(fuer gruppe: LeistungskatalogService.Tarifgruppe, in ctx: NSManagedObjectContext) -> Double {
        switch self {
        case .mops:
            return neutral(gruppe)
        case .goldschmitt:
            // Goldschmitts echte Werte aus den Stammdaten (keine hartkodierten Vertrauensdaten).
            let name: String
            switch gruppe {
            case .facharbeiter: name = "Facharbeiter (Raphael)"   // ZG1 → 74,00
            case .maschinist:   name = "Maschinenf."               // 30,00 × 1,70 → 51,00
            case .helfer:       name = "Helfer"                    // generischer Tarif → 28,68
            }
            return Self.lohnsatzWert(name, in: ctx) ?? neutral(gruppe)
        }
    }

    /// Liest `Lohnsatz.berechnungBruttoEK` zu einer Qualifikation aus den Stammdaten.
    private static func lohnsatzWert(_ qualifikation: String, in ctx: NSManagedObjectContext) -> Double? {
        let req: NSFetchRequest<Lohnsatz> = Lohnsatz.fetchRequest()
        req.fetchLimit = 1
        req.predicate = NSPredicate(format: "qualifikation ==[c] %@", qualifikation)
        guard let satz = (try? ctx.fetch(req))?.first else { return nil }
        return satz.berechnungBruttoEK
    }
}
