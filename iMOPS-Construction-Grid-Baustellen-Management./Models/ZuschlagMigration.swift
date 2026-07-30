import Foundation
import CoreData

/// Einmal-Migration: schützt bestehende Positionen davor, dass die neu eingeführten
/// FIRMENWERTE ihre eigenen Zuschlagssätze stillschweigend überschreiben.
///
/// Ab jetzt gilt: eine Position ohne `zuschlagEigen` rechnet mit den Firmenwerten.
/// Für Bestandsdaten wäre das eine Preisänderung, die niemand ausgelöst hat — die
/// Marktbreit-Pauschalposition etwa steht bewusst auf 0 % (Nachunternehmer-
/// Durchleitung) und bekäme plötzlich 20 % aufgeschlagen.
///
/// Deshalb wird beim ersten Start markiert, WER abweicht:
///   • Sätze == Firmenwerte  → `zuschlagEigen = false` ⇒ folgt ab jetzt der Firma.
///     Das ist der Normalfall und genau der Zweck der Übung.
///   • Sätze != Firmenwerte  → `zuschlagEigen = true`  ⇒ bleibt exakt, wie es war.
///
/// Damit ändert sich durch die Migration keine einzige Zahl.
struct ZuschlagMigration {

    private static let key = "zuschlag_firmenwerte_migrated"

    static func run(in context: NSManagedObjectContext) {
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let request: NSFetchRequest<LVPosition> = LVPosition.fetchRequest()
        guard let positionen = try? context.fetch(request) else {
            // Kein Zugriff auf den Store — NICHT als erledigt markieren, sonst
            // liefe die Migration nie wieder an.
            return
        }

        let firmenBGK = FirmenSettings.bgk
        let firmenWG = FirmenSettings.wagnisGewinn
        var abweichend = 0

        for pos in positionen {
            // Toleranz, weil die Werte als Double gespeichert sind.
            let weichtAb = abs(pos.bgkProzent - firmenBGK) > 0.0001
                || abs(pos.wagnisGewinnProzent - firmenWG) > 0.0001
            pos.zuschlagEigen = weichtAb
            if weichtAb { abweichend += 1 }
        }

        do {
            if context.hasChanges { try context.save() }
            UserDefaults.standard.set(true, forKey: key)
            print("ZuschlagMigration: \(positionen.count) Positionen geprüft, \(abweichend) weichen ab.")
        } catch {
            // Nicht als erledigt markieren — beim nächsten Start neu versuchen.
            print("ZuschlagMigration fehlgeschlagen: \(error)")
        }
    }
}
