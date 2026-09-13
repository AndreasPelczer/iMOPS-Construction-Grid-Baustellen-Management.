//
//  Event+Schichtuebergabe.swift
//  Die Schichtübergabe der ganzen Baustelle: EIN Akt übernimmt die Verantwortung
//  für alle offenen Aufträge. Logik hier (testbar, auch vom künftigen Wächter-Dienst
//  nutzbar), die Karte ruft nur auf.
//

import Foundation
import CoreData

extension Event {

    /// Die noch offenen (nicht fertigen) Aufträge dieser Baustelle.
    var offeneAuftraege: [Auftrag] {
        (jobs?.allObjects as? [Auftrag] ?? []).filter { !$0.istFertig }
    }

    /// Ist die Baustelle heute übernommen? = es gibt offene Aufträge und ALLE sind
    /// heute angenommen. (Keine offenen → nichts zu übernehmen.)
    var schichtHeuteUebernommen: Bool {
        let offen = offeneAuftraege
        guard !offen.isEmpty else { return false }
        return offen.allSatisfy { job in
            guard let am = AuftragExtrasPayload.from(job.extras).angenommenAm else { return false }
            return Calendar.current.isDateInToday(am)
        }
    }

    /// Wer hat zuletzt übernommen (Rolle), falls jemand.
    var schichtUebernommenVon: String? {
        offeneAuftraege.compactMap { AuftragExtrasPayload.from($0.extras).angenommenVon }.first
    }

    /// Übernimmt in EINEM Akt die Verantwortung für alle offenen Aufträge — der Moment
    /// der Schichtübergabe. Speichert NICHT (der Aufrufer macht ctx.save()).
    func schichtUebernehmen(rolle: String, ergebnis: Annahmeergebnis, am: Date = Date()) {
        for job in offeneAuftraege {
            var e = AuftragExtrasPayload.from(job.extras)
            e.angenommenVon = rolle
            e.angenommenAm = am
            e.annahmeErgebnis = ergebnis.rawValue
            job.extras = e.toJSONString()
        }
    }
}
