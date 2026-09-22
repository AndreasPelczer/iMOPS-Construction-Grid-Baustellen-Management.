//
//  PositionSchnellView.swift
//
//  Eine LV-Position anlegen — mit zwei Angaben: WAS und WIE VIEL.
//
//  Vorher gab es dafür drei Masken mit 10, 9 und 3 Feldern, je nachdem, von wo man kam.
//  Alle drei legen dasselbe an. Der Unterschied war nicht die Aufgabe, sondern wer wann
//  was gebraucht hat.
//
//  Die Regel hier: **Was der Mops wissen kann, fragt er nicht.** Positionsnummer,
//  Einheit, Preis, Kostengruppe und Geschoss kommen mit dem Textbaustein oder stehen
//  fest — sie werden gezeigt, nicht abgefragt. Wer sie ändern will, tippt sie an.
//
//  Warum der Textbaustein zählt: ein Tipp auf einen Vorschlag setzt den Text WORTGLEICH
//  wie im Katalog. Nur dann findet der Mops beim nächsten Mal sein eigenes Rezept wieder
//  und der Firmenpreis greift. Frei geschriebener Text sieht genauso aus, hat aber weder
//  Rezept noch Preis noch die richtige Kostengruppe.
//

import SwiftUI
import CoreData

struct PositionSchnellView: View {
    let event: Event
    /// Wird nach dem Anlegen aufgerufen — die aufrufende Ansicht entscheidet, was dann
    /// passiert (schließen, weitermachen, in den Canvas zurück).
    var fertig: ((LVPosition) -> Void)? = nil

    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @State private var suchtext = ""
    @State private var menge = ""
    @State private var gewaehlt: Vorschlag?
    @State private var vorschlaege: [Vorschlag] = []
    /// Vom Nutzer ueberschriebene Kostengruppe bzw. Geschoss (nil = Vorschlag gilt).
    @State private var kgGewaehlt: String?
    @State private var geschossGewaehlt: Geschoss?
    @State private var zeigeKGWahl = false
    /// Wenn nichts passt: eigene Leistung. Einheit und Preis muessen dann von Hand kommen.
    @State private var eigeneEinheit = "m²"
    @State private var eigenerPreis = ""
    @State private var inKatalog = true

    /// Ein Vorschlag, egal aus welchem Topf — der Nutzer soll den Unterschied nicht
    /// kennen müssen, nur den Preis sehen.
    struct Vorschlag: Identifiable {
        let id: String
        let text: String
        let einheit: String
        let preis: Double          // 0 = kommt aus dem Rezept
        let quelle: String
        let kostengruppe: String?
        var hatPreis: Bool { preis > 0 }
    }

    /// Die Kostengruppe. Erst die des Bausteins, sonst der Vorschlag aus dem Text.
    ///
    /// WICHTIG: Von den 1.043 importierten Firmen-Katalogzeilen hat KEINE eine
    /// Kostengruppe — die Preisliste kennt nur Name, Einheit und Preis. Ohne den
    /// Textvorschlag landeten alle auf „300" und damit im falschen Titel.
    private var kgVorschlag: (nummer: String, geraten: Bool) {
        if let kg = gewaehlt?.kostengruppe, !kg.isEmpty { return (kg, false) }
        let entwurf = LVDraftPosition(bezeichnung: suchtext, einheit: gewaehlt?.einheit ?? "")
        if let p = ExpertValidationService.proposeKG(for: entwurf) { return (p.suggestedKG, true) }
        return ("300", true)
    }
    private var kgEffektiv: String { kgGewaehlt ?? kgVorschlag.nummer }

    /// Freier Text ohne Katalogtreffer — der Nutzer legt etwas Neues an.
    private var istEigene: Bool {
        gewaehlt == nil && suchtext.trimmingCharacters(in: .whitespaces).count >= 3
    }
    private var eigenerPreisWert: Double {
        Double(eigenerPreis.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    /// Die Einheit, die gilt — vom Baustein oder selbst gewaehlt.
    private var einheitEffektiv: String { gewaehlt?.einheit ?? eigeneEinheit }

    private var mengeWert: Double {
        Double(menge.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    private var kannSichern: Bool { (gewaehlt != nil || istEigene) && mengeWert > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Was soll gemacht werden?", text: $suchtext, axis: .vertical)
                        .lineLimit(1...3)
                        .onChange(of: suchtext) { _, neu in suche(neu) }
                    ForEach(vorschlaege) { v in
                        Button { waehle(v) } label: { vorschlagZeile(v) }
                            .buttonStyle(.plain)
                    }
                } header: {
                    Text("Leistung")
                } footer: {
                    Text(fusszeile)
                }

                if let g = gewaehlt {
                    Section("Menge") {
                        HStack {
                            TextField("0,00", text: $menge)
                                .keyboardType(.decimalPad)
                            Text(g.einheit).foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Gesamt")
                            Spacer()
                            Text(gesamtText()).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }

                    Section {
                        zeile("Position", naechstePosNr())

                        Button { zeigeKGWahl = true } label: {
                            HStack {
                                Text("Kostengruppe").foregroundStyle(.primary)
                                Spacer()
                                Text(kgEffektiv).foregroundStyle(.secondary)
                                if kgGewaehlt == nil && kgVorschlag.geraten {
                                    Image(systemName: "questionmark.circle")
                                        .font(.caption2).foregroundStyle(.orange)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                        }

                        Picker("Geschoss", selection: $geschossGewaehlt) {
                            Text("—").tag(Geschoss?.none)
                            ForEach(HierarchieHelfer.alleGeschosse(for: event), id: \.objectID) { g in
                                Text(g.name ?? "Geschoss").tag(Geschoss?.some(g))
                            }
                        }
                    } header: {
                        Text("Setzt der Mops")
                    } footer: {
                        Text(kgGewaehlt == nil && kgVorschlag.geraten
                             ? "Die Kostengruppe ist aus dem Text geraten — bitte prüfen. "
                               + "Sie bestimmt, in welchem Titel die Position landet."
                             : "Antippen zum Ändern, falls es nicht stimmt.")
                    }
                }
            }
            .sheet(isPresented: $zeigeKGWahl) {
                KGPickerList(selected: Binding(
                    get: { kgEffektiv },
                    set: { kgGewaehlt = $0; zeigeKGWahl = false }))
            }
            .navigationTitle("Neue Position")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { sichern() }
                        .disabled(!kannSichern)
                        .tint(.orange)
                }
            }
        }
    }

    // MARK: - Teile

    private func vorschlagZeile(_ v: Vorschlag) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(v.text).font(.subheadline).lineLimit(2)
                Text(v.quelle).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(v.hatPreis ? v.preis.formatted(.currency(code: "EUR")) : "Rezept")
                .font(.caption.monospacedDigit())
                .foregroundStyle(v.hatPreis ? .green : .secondary)
        }
    }

    private func zeile(_ titel: String, _ wert: String) -> some View {
        HStack { Text(titel); Spacer(); Text(wert).foregroundStyle(.secondary) }
    }

    private var fusszeile: String {
        if let g = gewaehlt {
            return g.hatPreis
                ? "Preis \(g.preis.formatted(.currency(code: "EUR"))) je \(g.einheit) — aus \(g.quelle)"
                : "Der Preis wird aus dem Rezept gerechnet."
        }
        return suchtext.count < 3
            ? "Ab drei Buchstaben schlägt der Mops aus eurem Katalog vor."
            : "Kein Treffer — du kannst den Text auch frei schreiben, dann fehlt aber der Preis."
    }

    private func gesamtText() -> String {
        guard mengeWert > 0 else { return "—" }
        let preis = gewaehlt?.preis ?? eigenerPreisWert
        if preis > 0 { return (preis * mengeWert).formatted(.currency(code: "EUR")) }
        return gewaehlt != nil ? "aus Rezept" : "—"
    }

    // MARK: - Suche in BEIDEN Katalogen

    private func suche(_ text: String) {
        gewaehlt = nil
        let s = text.trimmingCharacters(in: .whitespaces)
        guard s.count >= 3 else { vorschlaege = []; return }

        // 1) Der eigene Katalog zuerst — an seinen Zeilen hängt der eigene Preis.
        let firma = LeistungskatalogService.vorschlaege(fuer: s, limit: 6, in: ctx).map {
            Vorschlag(id: $0.objectID.uriRepresentation().absoluteString,
                      text: $0.leistung ?? "",
                      einheit: $0.einheit ?? "psch",
                      preis: $0.einheitspreisVK,
                      quelle: $0.quelle ?? "eigener Katalog",
                      kostengruppe: $0.kostenGruppeNummer)
        }
        // 2) Dann die Rezept-Bausteine — sie rechnen Lohn und Material aus.
        let rezepte = STLBKatalog.shared.vorschlaege(zu: s).prefix(4).map {
            Vorschlag(id: $0.id, text: $0.kurztext, einheit: $0.einheit, preis: 0,
                      quelle: "Rezept · \($0.gewerk)", kostengruppe: $0.din)
        }
        // Exakter Treffer = gerade gepickt → Liste zu.
        let alle = firma + rezepte
        vorschlaege = alle.contains { $0.text == s } ? [] : alle
    }

    private func waehle(_ v: Vorschlag) {
        gewaehlt = v
        kgGewaehlt = nil          // neue Leistung -> neuer Vorschlag
        suchtext = v.text          // WORTGLEICH — sonst findet der Matcher nichts wieder
        vorschlaege = []
    }

    // MARK: - Anlegen

    /// Dieselbe Regel wie im Baustein-Browser: Titel „01", Positionen in 10er-Schritten
    /// (01.0010, 01.0020 …). Das ist Raphis Muster aus den echten Goldschmitt-Angeboten —
    /// die Luecken erlauben spaeteres Einschieben, ohne alles umzunummerieren.
    private func naechstePosNr(titel: String = "01") -> String {
        let prefix = "\(titel)."
        let vorhanden = ((event.lvPositionen?.allObjects as? [LVPosition]) ?? [])
            .compactMap(\.posNr)
            .filter { $0.hasPrefix(prefix) }
        let maxSuffix = vorhanden
            .compactMap { Int($0.split(separator: ".").last ?? "") }
            .max() ?? 0
        let next = ((maxSuffix / 10) + 1) * 10
        return "\(titel).\(String(format: "%04d", next))"
    }

    private func sichern() {
        guard mengeWert > 0 else { return }
        let text = gewaehlt?.text ?? suchtext.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        let pos = LVPosition(context: ctx)
        pos.posNr = naechstePosNr()
        pos.bezeichnung = text
        pos.einheit = einheitEffektiv
        pos.menge = mengeWert
        pos.kostenGruppeNummer = kgEffektiv
        pos.event = event
        if let ge = geschossGewaehlt ?? HierarchieHelfer.defaultGeschoss(for: event) {
            pos.geschoss = ge
        }

        let preis = gewaehlt?.preis ?? eigenerPreisWert

        // Preis als Angebot anhängen — derselbe Weg wie beim Preislisten-Import, damit
        // effektiverEP ihn findet. Die permanente objectID ist Pflicht: unter der
        // temporären wäre der Preis nach dem Speichern nicht mehr auffindbar.
        if preis > 0 {
            try? ctx.obtainPermanentIDs(for: [pos])
            let id = pos.objectID.uriRepresentation().absoluteString
            let lieferant = gewaehlt?.quelle ?? "selbst eingetragen"
            AngebotsStore.shared.upsert(Angebot(lieferant: lieferant, einzelpreis: preis),
                                        for: id)
        } else if gewaehlt != nil {
            // Rezept-Baustein ohne festen Preis → rechnen lassen.
            _ = LeistungskatalogService.autoMatch(position: pos, in: ctx)
        }

        // DER KATALOG LERNT — beide Richtungen:
        //
        // 1) Etwas Neues wandert hinein, damit es beim nächsten Mal vorgeschlagen wird.
        //    Ohne das bleibt der Katalog auf dem Stand des letzten Imports stehen und
        //    jeder tippt dieselbe Leistung wieder von Hand.
        if istEigene && inKatalog {
            let b = LeistungskatalogService.merke(
                leistung: text, einheit: einheitEffektiv,
                maurer: 0, helfer: 0,
                kostenGruppeNummer: kgEffektiv,
                quelle: "selbst eingetragen", in: ctx)
            b.einheitspreisVK = eigenerPreisWert
            LeistungskatalogService.benutzt(b)
        }
        // 2) Ein gepickter Baustein wird als benutzt vermerkt — häufige stehen dann oben.
        //    `benutzt(_:)` gab es längst, wurde aber von NIEMANDEM aufgerufen: der Zähler
        //    stand bei allen Bausteinen auf 0, die Sortierung lief immer alphabetisch.
        if let g = gewaehlt, let b = LeistungskatalogService.finde(leistung: g.text,
                                                                  einheit: g.einheit, in: ctx) {
            LeistungskatalogService.benutzt(b)
        }

        try? ctx.save()
        fertig?(pos)
        dismiss()
    }
}
