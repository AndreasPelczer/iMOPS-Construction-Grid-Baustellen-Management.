//
//  AnweisungsAssistent.swift
//
//  „Mops, wie geht das?" — der vorhandene Prof-Weg, für Arbeitsschritte.
//
//  Andreas, 21.09.2026: „Jetzt der seltene Fall, wo ich bewusst KI einsetzen darf?
//  Ich brauch die Schritte, ich hab's mal gelernt, ich frag Gemini, Antwort gefällt
//  mir, kann ich so verantworten." — und gleich darauf die Korrektur: „Ich denke an
//  den Prof-Knopf, den wir schon haben. Wir haben doch den Mops-Server mit einer
//  eigenen KI, rudimentär, aber im Aufbau, mit Fallback zur Claude-API."
//
//  Er hat recht, und der Unterschied ist groß: nicht er fragt und tippt ab, sondern
//  DER MOPS fragt und er nimmt ab. Dann bleibt es bei ihm (eigene Box), die Herkunft
//  schreibt sich von selbst mit, und beim nächsten Mal ist es schon da.
//
//  🔴 Die wichtigste Zeile steckt in der Frage selbst: „Erfinde keine Zahlenwerte."
//  Ein Wert, der gar nicht erst entsteht, muss später nicht geprüft werden. Das löst
//  die Hälfte des Problems an der Quelle — die andere Hälfte macht `Werterkennung`.
//
//  Verwendet `MopsClient.ask(useProf:)` — denselben Weg, den `MopsKalkulationsHelper`
//  schon fünfmal geht. Nichts Neues, nur verkabelt.
//

import Foundation
import CoreData

enum AnweisungsAssistent {

    /// Was der Mops über diese Arbeit weiß, als Frage formuliert.
    ///
    /// Bewusst MIT Material und Gerät aus dem Rezept: dann sind die Schritte an den
    /// echten Daten entlang geschrieben und nicht frei erfunden.
    @MainActor
    static func frage(fuer job: Auftrag) -> String {
        let leistung = Kausalkette.bezeichnung(job)
        var zeilen = ["Leistung: \(leistung)"]

        if let pos = job.lvPosition {
            if let einheit = pos.einheit, !einheit.isEmpty {
                zeilen.append("Menge: \(pos.menge.formatted(.number.precision(.fractionLength(0...2)))) \(einheit)")
            }
            let material = pos.materialArray.compactMap { $0.materialName }.prefix(6)
            if !material.isEmpty { zeilen.append("Material laut Rezept: " + material.joined(separator: ", ")) }
            let geraet = pos.geraeteArray.compactMap { $0.geraetName }.prefix(4)
            if !geraet.isEmpty { zeilen.append("Gerät laut Rezept: " + geraet.joined(separator: ", ")) }
        }
        if let kg = job.kostenGruppeNummer, !kg.isEmpty {
            zeilen.append("Kostengruppe: \(kg) \(DIN276KostenGruppe.bezeichnung(fuer: kg))")
        }

        return """
        Arbeitsschritte für eine Baustellen-Aufgabe.

        \(zeilen.joined(separator: "\n"))

        Antworte NUR mit einer nummerierten Liste, ein Schritt je Zeile, keine Einleitung.
        Regeln:
        - 5 bis 10 Schritte, in der Reihenfolge der Ausführung
        - jeder Schritt ein kurzer Satz im Imperativ
        - Prüf- und Abnahmeschritte nicht vergessen
        - ERFINDE KEINE ZAHLENWERTE. Wo ein Wert nötig ist, schreib "nach Vorgabe" \
        oder "laut Plan" statt einer Zahl.
        """
    }

    /// Fragt den Mops. Ohne Server kommt ein ehrlicher Fehler, keine erfundene Liste.
    @MainActor
    static func hole(fuer job: Auftrag,
                     client: MopsClient = MopsClient()) async throws -> [AnweisungsSchritt] {
        let antwort = try await client.ask(question: frage(fuer: job), useProf: true)
        return schritteAus(antwort.answer, modell: antwort.model)
    }

    // MARK: - Antwort zerlegen

    /// Macht aus der Antwort eine Liste. Nummerierung, Spiegelstriche und
    /// Einleitungssätze fliegen raus.
    static func schritteAus(_ antwort: String, modell: String? = nil) -> [AnweisungsSchritt] {
        antwort
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { zeile -> String in
                var t = zeile.trimmingCharacters(in: .whitespaces)
                // „1. ", „1) ", „- ", „• ", „* "
                t = t.replacingOccurrences(of: #"^\s*(\d{1,2}[.)]\s*|[-•*]\s*)"#,
                                           with: "", options: .regularExpression)
                return t.trimmingCharacters(in: .whitespaces)
            }
            .filter { t in
                guard t.count >= 6, t.count <= 160 else { return false }
                // Einleitungen und Überschriften aussortieren
                let k = t.lowercased()
                if k.hasSuffix(":") { return false }
                if k.contains("arbeitsschritte für") || k.hasPrefix("hier ") { return false }
                return true
            }
            .map { text in
                AnweisungsSchritt(text: text,
                                  herkunft: .prof,
                                  modell: modell,
                                  traegtWert: Werterkennung.traegtWert(text))
            }
    }

    // MARK: - Aus dem Rezept, ganz ohne KI

    /// Das Gerüst, das aus den EIGENEN Daten kommt — nichts geraten, alles belegt.
    /// Mager, aber wahr. Steht als Rückfall bereit, wenn der Server nicht antwortet.
    @MainActor
    static func ausRezept(_ job: Auftrag) -> [AnweisungsSchritt] {
        var schritte: [AnweisungsSchritt] = []
        guard let pos = job.lvPosition else { return schritte }

        let material = pos.materialArray.compactMap { $0.materialName }
        if !material.isEmpty {
            schritte.append(AnweisungsSchritt(
                text: "Material bereitstellen: " + material.prefix(4).joined(separator: ", "),
                herkunft: .rezept, traegtWert: false))
        }
        let geraet = pos.geraeteArray.compactMap { $0.geraetName }
        if !geraet.isEmpty {
            schritte.append(AnweisungsSchritt(
                text: "Gerät holen: " + geraet.prefix(3).joined(separator: ", "),
                herkunft: .rezept, traegtWert: false))
        }
        if !schritte.isEmpty {
            schritte.append(AnweisungsSchritt(text: "Ausführen", herkunft: .rezept))
            schritte.append(AnweisungsSchritt(text: "Aufmaß nehmen", herkunft: .rezept))
        }
        return schritte
    }
}
