//
//  Auftrag+Baustelleneinrichtung.swift
//  Ein Ort für die Frage „gehört dieser Auftrag zur Baustelleneinrichtung?" —
//  damit Ampel (roter Punkt) und Kausalbaukette (Glied 2) dieselbe Wahrheit nutzen.
//

import Foundation
import CoreData

extension Auftrag {

    /// Gehört dieser Auftrag zur Baustelleneinrichtung?
    /// Zuerst am ECHTEN Gewerk (aus den extras), dann am Titel-Wortstamm — der Stamm
    /// „einricht" deckt „einrichten" UND „einrichtung" ab (der alte Filter suchte nur
    /// „einrichtung" und verfehlte „Baustelle einrichten …"), plus Absicherung und die
    /// klassische Infrastruktur (Bauzaun/Baustrom/Bauwasser).
    var istBaustelleneinrichtung: Bool {
        if AuftragExtrasPayload.from(extras).gewerk == "Baustelleneinrichtung" { return true }
        let d = (processingDetails ?? "").lowercased()
        return d.contains("einricht") || d.contains("absicher")
            || d.contains("bauzaun") || d.contains("baustrom") || d.contains("bauwasser")
    }
}
