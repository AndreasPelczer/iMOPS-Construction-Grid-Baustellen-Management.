//
//  Auftrag+Uebergabe.swift
//  Der Übergabe-Zustand eines Auftrags (zweiseitig, Buch „Thermodynamik der Arbeit").
//  Abgabe = „bin fertig / Feierabend"; Annahme = der Nächste übernimmt und meldet.
//  Der Mops ist STILL, solange die Kette hält — er meldet nur die offene Lücke.
//

import Foundation
import CoreData

extension Auftrag {

    private var uebergabeExtras: AuftragExtrasPayload { AuftragExtrasPayload.from(extras) }

    /// Abgegeben (jemand hat die Verantwortung hingelegt — Feierabend / fertig gemeldet).
    var istAbgegeben: Bool { uebergabeExtras.abgegebenAm != nil }

    /// Angenommen (der Nächste hat die Verantwortung aufgenommen).
    var istAngenommen: Bool { uebergabeExtras.angenommenAm != nil }

    /// DIE LÜCKE: abgegeben, aber (noch) nicht angenommen. Genau das — und nur das —
    /// macht der Mops sichtbar; sonst bleibt er still (Kap 10 „Gute Systeme sind still").
    var uebergabeOffen: Bool { istAbgegeben && !istAngenommen }

    /// Ergebnis der Annahme, falls angenommen (ok / problem / geht nicht).
    var annahmeErgebnis: Annahmeergebnis? {
        guard let r = uebergabeExtras.annahmeErgebnis else { return nil }
        return Annahmeergebnis(rawValue: r)
    }

    /// Es gibt einen gemeldeten Befund bei der Annahme (Problem / geht nicht) — kein
    /// Lücken-Alarm, aber ein sichtbarer Zustand.
    var annahmeMitBefund: Bool {
        if let e = annahmeErgebnis { return !e.haeltDieKette }
        return false
    }
}
