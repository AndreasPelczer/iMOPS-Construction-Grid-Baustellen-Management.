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
    /// der Schichtübergabe (morgens). Speichert NICHT (der Aufrufer macht ctx.save()).
    func schichtUebernehmen(rolle: String, ergebnis: Annahmeergebnis, am: Date = Date()) {
        for job in offeneAuftraege {
            var e = AuftragExtrasPayload.from(job.extras)
            e.angenommenVon = rolle
            e.angenommenAm = am
            e.annahmeErgebnis = ergebnis.rawValue
            job.extras = e.toJSONString()
        }
    }

    /// Feierabend: legt in EINEM Akt die Verantwortung für alle offenen Aufträge hin
    /// (Abgabe). Eine alte Annahme gilt danach nicht mehr — frische Übergabe. Speichert NICHT.
    func schichtAbgeben(rolle: String, am: Date = Date()) {
        for job in offeneAuftraege {
            var e = AuftragExtrasPayload.from(job.extras)
            e.abgegebenVon = rolle
            e.abgegebenAm = am
            e.angenommenVon = nil
            e.angenommenAm = nil
            e.annahmeErgebnis = nil
            job.extras = e.toJSONString()
        }
    }

    /// Es liegt eine offene Übergabe an: mindestens ein offener Auftrag ist abgegeben,
    /// aber weder angenommen noch besprochen. Der Mops erinnert daran — freundlich, kein
    /// Alarm, und immer nur als Angebot: übernehmen ODER „haben wir besprochen" ODER
    /// nichts tun (die Wahl bleibt beim Menschen — vielleicht mögen sie sich nicht).
    var hatOffeneUebergabe: Bool {
        offeneAuftraege.contains { $0.uebergabeOffen }
    }

    /// „Haben wir besprochen": klärt die offene Übergabe mündlich, ohne formales
    /// Quittieren. Schließt die Lücke, hinterlässt aber die Spur (wer/wann). Speichert NICHT.
    func schichtBesprochen(rolle: String, am: Date = Date()) {
        for job in offeneAuftraege where job.uebergabeOffen {
            var e = AuftragExtrasPayload.from(job.extras)
            e.besprochenVon = rolle
            e.besprochenAm = am
            job.extras = e.toJSONString()
        }
    }

    /// Wurde die Übergabe mündlich geklärt (statt formal übernommen)?
    var hatBesprocheneUebergabe: Bool {
        let offen = offeneAuftraege
        guard offen.contains(where: { $0.istBesprochen }) else { return false }
        // Alle abgegebenen sind entweder angenommen oder besprochen (nichts mehr offen).
        return !offen.contains { $0.uebergabeOffen }
    }
}
