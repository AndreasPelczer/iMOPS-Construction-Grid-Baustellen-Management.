//
//  AmpelCard.swift
//  iMOPS-Construction-Grid-Baustellen-Management.
//
//  Created by Andreas Pelczer on 21.06.26.
//
import SwiftUI

struct AmpelCard: View {
    @ObservedObject var event: Event

    // 🔗 DIE KAUSALBAUKETTE: Sequentielle Prüfung von oben nach unten
    private var ampelStatus: (farbe: Color, text: String, subtext: String) {
        
        // -----------------------------------------------------------------
        // GLIED 1 & 2: RECHTLICH & BEHÖRDLICH (Die harte iMOPS-Bremse)
        // -----------------------------------------------------------------
        let baugenehmigung = event.baugenehmigungNr?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if baugenehmigung.isEmpty {
            return (
                .red,
                "Baustart BLOCKIERT",
                "Keine Baugenehmigungsnummer hinterlegt. Operative Gewerke gesperrt."
            )
        }
        
        // -----------------------------------------------------------------
        // GLIED 3: INFRASTRUCTUR (Baustrom, Bauwasser, Bauzaun)
        // -----------------------------------------------------------------
        let auftraege = event.jobs?.allObjects as? [Auftrag] ?? []

        // -----------------------------------------------------------------
        // DIE ÜBERGABE-LÜCKE — das Einzige, wo der Mops von sich aus spricht.
        // Buch: „Gute Systeme sind still" (Kap 10). Solange die Kette hält, sagt er
        // nichts. Abgegeben, aber keiner hat übernommen = die Lücke:
        //   über Nacht offen  → 🔴 keiner hat den Staffelstab aufgehoben.
        //   heute abgegeben    → 🟠 wartet auf den Nächsten (noch okay).
        // -----------------------------------------------------------------
        let offeneUebergaben = auftraege.filter { $0.uebergabeOffen }
        let ueberNacht = offeneUebergaben.first {
            guard let am = AuftragExtrasPayload.from($0.extras).abgegebenAm else { return false }
            return !Calendar.current.isDateInToday(am)
        }
        if let job = ueberNacht {
            return (
                .red,
                "Übergabe offen",
                "\(job.processingDetails ?? "Ein Auftrag") wurde abgegeben, aber niemand hat übernommen."
            )
        }
        if !offeneUebergaben.isEmpty {
            return (
                .orange,
                "Wartet auf Übernahme",
                "Ein Auftrag ist abgegeben und wartet auf den Nächsten."
            )
        }
        // Bei der Annahme ein Befund gemeldet (Problem / geht nicht) → sichtbar machen.
        if let befund = auftraege.first(where: { $0.annahmeMitBefund }) {
            return (
                .orange,
                "Problem bei Übernahme",
                "\(befund.processingDetails ?? "Ein Auftrag"): \(befund.annahmeErgebnis?.titel ?? "gemeldet")."
            )
        }

        // Baustelleneinrichtung am ECHTEN Gewerk erkennen (nicht am Titel raten), und
        // ehrlich unterscheiden: existiert sie und läuft (🟠) — oder ist sie gar nicht da?
        let infraJobs = auftraege.filter { $0.istBaustelleneinrichtung }
        let infraOffen = infraJobs.filter { !$0.istFertig }
        if !infraOffen.isEmpty {
            // Sie ist im Graph eingerichtet, nur noch nicht ganz übernommen → „läuft",
            // NICHT „fehlt". Wir zeigen den echten Stand aus der Checkliste.
            let (uebernommen, gesamt) = einrichtungsFortschritt(infraOffen)
            let stand = gesamt > 0 ? " (\(uebernommen)/\(gesamt) Schritte übernommen)" : ""
            return (
                .orange,
                "Baustelleneinrichtung läuft",
                "Eingerichtet, aber noch nicht abgeschlossen\(stand). Teilweise Baufreiheit."
            )
        }
        
        // -----------------------------------------------------------------
        // GLIED 4: OPERATIV & QUALITÄT (Laufende Arbeiten & Mängel)
        // -----------------------------------------------------------------
        let offeneMaengel = (event.maengel?.allObjects as? [Mangel] ?? [])
            .filter { $0.status == .offen || $0.status == .inArbeit }.count
        
        if offeneMaengel > 0 {
            return (
                .red,
                "Mängel offen (\(offeneMaengel))",
                "Qualitätsmängel blockieren die nächste Abnahme-Stufe."
            )
        }
        
        // Prüfen, ob noch reguläre Handwerker-Aufträge offen sind
        let handwerkOffen = auftraege.contains(where: { !$0.istFertig })
        if handwerkOffen {
            return (
                .orange,
                "Gewerke in Arbeit",
                "Baugenehmigung erteilt, Infrastruktur steht. Handwerker sind aktiv."
            )
        }

        // -----------------------------------------------------------------
        // ZIEL: ALLES ERLEDIGT
        // -----------------------------------------------------------------
        if !auftraege.isEmpty && auftraege.allSatisfy({ $0.istFertig }) {
            return (
                .green,
                "Baufreiheit vollständig erteilt",
                "Alle Aufträge abgeschlossen, keine offenen Mängel. Projekt bereit zur Abnahme."
            )
        }

        // Default-Sicherheitsnetz
        return (
            .gray,
            "Wartet auf Start",
            "Projekt angelegt. Kausalbaukette bereit zur Validierung."
        )
    }

    // (istBaustelleneinrichtung liegt jetzt als geteilte Auftrag-Erweiterung vor —
    //  dieselbe Wahrheit für Ampel und Kausalbaukette.)

    // Wie weit ist die Einrichtung? Summe der übernommenen vs. aller Schritte über die
    // offenen Einrichtungs-Aufträge — der echte Stand aus dem Graph, nicht geraten.
    private func einrichtungsFortschritt(_ jobs: [Auftrag]) -> (uebernommen: Int, gesamt: Int) {
        var done = 0, total = 0
        for job in jobs {
            let liste = AuftragExtrasPayload.from(job.extras).checklist
            done += liste.filter { $0.isDone }.count
            total += liste.count
        }
        return (done, total)
    }

    // Faden gemessen/geschätzt (Welle-9-Ziel „Schätzwerte andersfarbig bis gemessen"):
    // Positionen, deren Menge noch eine Schätzung ist (nicht harte Statik) UND die noch
    // kein Aufmaß haben → „noch nicht belastbar". Kein Baufrei-Blocker, nur ein ehrlicher
    // Hinweis auf die Datengüte.
    private var geschaetztOffen: Int {
        ((event.lvPositionen?.allObjects as? [LVPosition]) ?? [])
            .filter { $0.istGeschaetzt && !$0.hatAufmass }.count
    }

    var body: some View {
        HStack(spacing: 16) {
            // Die leuchtende iMOPS-Ampel
            Circle()
                .fill(ampelStatus.farbe)
                .frame(width: 50, height: 50)
                .shadow(color: ampelStatus.farbe.opacity(0.5), radius: 8)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.4), lineWidth: 2)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(ampelStatus.text)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(ampelStatus.subtext)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if geschaetztOffen > 0 {
                    Label("\(geschaetztOffen) Position\(geschaetztOffen == 1 ? "" : "en") noch geschätzt (nicht gemessen)",
                          systemImage: "ruler")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
