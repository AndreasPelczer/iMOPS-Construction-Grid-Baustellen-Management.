//
//  PaketZuordnung.swift
//
//  Welche LV-Positionen gehören zu welchem Arbeitspaket — wenn nicht die
//  Titelnummer entscheidet.
//
//  🔴 Warum es das braucht: `Auftrag.lvPosition` ist im Datenmodell eine 1:1-Beziehung.
//  Setzt man mehrere Positionen auf denselben Auftrag, überschreibt jede die vorige.
//  Ein Arbeitspaket hat aber viele Positionen. Solange das Modell so ist, wird die
//  Zugehörigkeit über die Titelnummer GERECHNET — und wer ein Paket teilt, braucht
//  eine Stelle, an der die Ausnahme steht.
//
//  Das ist diese Datei. Wie LiegezeitBuch und SonderfallBuch: JSON in Documents,
//  keine Migration. Wenn `Auftrag.lvPosition` irgendwann toMany wird, wandert der
//  Inhalt hier einmalig hinüber und die Datei kann weg.
//
//  Andreas, 22.09.2026, zur Ursache: „was hat der Mops oder das LV oder wer auch
//  immer falsch gemacht? Wie konnte das überhaupt entstehen?" — Die DIN 276 ist eine
//  KOSTENgliederung. „411 Abwasser-, Wasser-, Gasanlagen" umfasst den Hausanschluss
//  im Graben UND das Waschbecken im Dachgeschoss. Für die Kalkulation richtig, für
//  den Bauablauf unbrauchbar.
//

import Foundation
import CoreData
import os

final class PaketZuordnung {

    static let shared = PaketZuordnung()
    private let logger = Logger(subsystem: "io.imops", category: "Pakete")

    /// Auftrags-Kennung → Positionsnummern, die ihm ausdrücklich gehören.
    private var zuordnung: [String: [String]] = [:]
    private let datei: URL

    private init() {
        let ordner = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        datei = ordner.appendingPathComponent("paketzuordnung.json")
        laden()
    }

    static func kennung(_ auftrag: Auftrag) -> String {
        auftrag.objectID.uriRepresentation().absoluteString
    }

    // MARK: Lesen

    /// Die Positionsnummern, die diesem Paket ausdrücklich gehören — leer, wenn es
    /// nie geteilt wurde.
    func posNummern(fuer auftrag: Auftrag) -> [String] {
        zuordnung[Self.kennung(auftrag)] ?? []
    }

    /// 🔴 Gehört diese Position einem ANDEREN Paket? Dann darf die Titelnummer sie
    /// hier nicht mehr einsammeln — sonst stünde sie nach dem Teilen in beiden.
    func gehoertWoandershin(_ posNr: String, ausser auftrag: Auftrag) -> Bool {
        let eigene = Self.kennung(auftrag)
        return zuordnung.contains { kennung, nummern in
            kennung != eigene && nummern.contains(posNr)
        }
    }

    // MARK: Schreiben

    func setzen(_ posNummern: [String], fuer auftrag: Auftrag) {
        let k = Self.kennung(auftrag)
        if posNummern.isEmpty { zuordnung.removeValue(forKey: k) }
        else { zuordnung[k] = posNummern.sorted() }
        sichern()
        logger.info("Paket-Zuordnung: \(posNummern.count) Positionen an \(k, privacy: .public)")
    }

    /// Beim Löschen eines Auftrags aufräumen — sonst bleibt eine Karteileiche.
    func vergessen(_ auftrag: Auftrag) {
        zuordnung.removeValue(forKey: Self.kennung(auftrag))
        sichern()
    }

    // MARK: Datei

    private func laden() {
        guard let data = try? Data(contentsOf: datei) else { return }
        zuordnung = (try? JSONDecoder().decode([String: [String]].self, from: data)) ?? [:]
    }

    private func sichern() {
        do {
            try JSONEncoder().encode(zuordnung).write(to: datei, options: .atomic)
        } catch {
            logger.error("Zuordnung nicht gesichert: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Für Tests.
    func leeren() {
        zuordnung = [:]
        try? FileManager.default.removeItem(at: datei)
    }
}
