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

    // MARK: - Lohn-KOSTEN je Profil
    //
    // Wichtig: Das Profil führt **Kosten** — was eine Stunde den Betrieb KOSTET
    // (Brutto-Lohn × Lohnnebenkosten), OHNE Gewinn/BGK/AGK. Der Verkaufspreis (z. B. Goldschmitts
    // 74 €/h Verrechnungssatz) entsteht darüber über die Zuschläge / den Gewinn-Schieber und ist
    // NICHT dieser Satz. So vergleichen Goldschmitt und Mops Äpfel mit Äpfeln (Kosten vs. Kosten).

    /// Lohnnebenkosten-Faktor je Tarifgruppe (nur Nebenkosten, kein Aufschlag).
    private func nebenkostenFaktor(_ g: LeistungskatalogService.Tarifgruppe) -> Double {
        g == .helfer ? 1.55 : 1.65
    }

    /// Brutto-Stundenlohn je Tarifgruppe. Mops = neutraler Bau-Tarif; Goldschmitt = ihre ECHTEN
    /// Löhne aus den Stammdaten (nur der Facharbeiter-Brutto ist als echte Zahl bekannt), sonst neutral.
    private func bruttoLohn(fuer g: LeistungskatalogService.Tarifgruppe, in ctx: NSManagedObjectContext) -> Double {
        let neutral: Double
        switch g {
        case .helfer:       neutral = 18.50
        case .facharbeiter: neutral = 28.50
        case .maschinist:   neutral = 30.00
        }
        guard self == .goldschmitt, g == .facharbeiter else { return neutral }
        // Goldschmitts echter Facharbeiter-Brutto (Lohnsatz.stundenlohn, NICHT der 74er-Kalkpreis).
        return Self.stundenlohn("Facharbeiter (Raphael)", in: ctx)
            ?? Self.stundenlohn("Spezialfacharbeiter", in: ctx)
            ?? neutral
    }

    /// Lohn-KOSTEN je Stunde für eine Tarifgruppe im gewählten Profil = Brutto × Nebenkosten.
    func satz(fuer gruppe: LeistungskatalogService.Tarifgruppe, in ctx: NSManagedObjectContext) -> Double {
        bruttoLohn(fuer: gruppe, in: ctx) * nebenkostenFaktor(gruppe)
    }

    /// Liest `Lohnsatz.stundenlohn` (Brutto, ohne Faktor) zu einer Qualifikation aus den Stammdaten.
    private static func stundenlohn(_ qualifikation: String, in ctx: NSManagedObjectContext) -> Double? {
        let req: NSFetchRequest<Lohnsatz> = Lohnsatz.fetchRequest()
        req.fetchLimit = 1
        req.predicate = NSPredicate(format: "qualifikation ==[c] %@", qualifikation)
        guard let satz = (try? ctx.fetch(req))?.first, satz.stundenlohn > 0 else { return nil }
        return satz.stundenlohn
    }
}
