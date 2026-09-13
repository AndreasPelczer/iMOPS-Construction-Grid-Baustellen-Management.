
//
//  KausalbauketteView.swift
//  iMOPS-Construction-Grid-Baustellen-Management.
//
//  Die interaktive Schaltzentrale für die Kausalbaukette.
//

import SwiftUI
import CoreData

struct KausalbauketteView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    @ObservedObject var event: Event
    
    // Lokaler State für die direkte Eingabe im Kettenglied
    @State private var baugenehmigungEingabe: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                // -----------------------------------------------------------------
                // GLIED 1: BEHÖRDLICHES FREIGABE-GLIED
                // -----------------------------------------------------------------
                Section(header: Label("Glied 1: Behörden & Recht", systemImage: "doc.balance")) {
                    if event.baugenehmigungNr?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            VStack(alignment: .leading) {
                                Text("Baugenehmigung liegt vor").font(.subheadline).bold()
                                Text("Nr: \(event.baugenehmigungNr ?? "")").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                                Text("Baugenehmigung fehlt!").font(.subheadline).bold()
                            }
                            Text("Ohne Genehmigungsnummer sind alle operativen Handwerker-Gewerke für den Mops gesperrt.")
                                .font(.caption).foregroundStyle(.secondary)
                            
                            // DIREKTEINGABE: Beseitigt den Engpass sofort!
                            HStack {
                                TextField("Nummer eingeben...", text: $baugenehmigungEingabe)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                                
                                Button("Fixieren") {
                                    let bereinigt = baugenehmigungEingabe.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !bereinigt.isEmpty {
                                        event.baugenehmigungNr = bereinigt
                                        try? viewContext.save()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                                .disabled(baugenehmigungEingabe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // -----------------------------------------------------------------
                // GLIED 2: INFRASTRUKTUR-GLIED
                // -----------------------------------------------------------------
                Section(header: Label("Glied 2: Baustelleneinrichtung", systemImage: "hammer.fill")) {
                    let infraJobs = holeInfrastrukturJobs()
                    if infraJobs.isEmpty {
                        Text("Keine Infrastruktur-Aufträge im System definiert.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        // Gesamtstatus: grün, sobald alle Einrichtungs-Aufträge übernommen sind.
                        let alleFertig = infraJobs.allSatisfy { $0.istFertig }
                        HStack(spacing: 8) {
                            Circle().fill(alleFertig ? Color.green : Color.orange).frame(width: 9, height: 9)
                            Text(alleFertig ? "Baustelle eingerichtet" : "Einrichtung läuft")
                                .font(.subheadline).bold()
                            Spacer()
                        }
                        ForEach(infraJobs, id: \.objectID) { job in
                            HStack {
                                Image(systemName: job.istFertig ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(job.istFertig ? .green : .orange)
                                
                                VStack(alignment: .leading) {
                                    Text(job.processingDetails ?? "Einrichtungs-Schritt").font(.subheadline)
                                    Text(job.istFertig ? "Erledigt" : "Offen / In Vorbereitung").font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                
                                // Schnelles Umschalten direkt in der Kette
                                Button(job.istFertig ? "Öffnen" : "Erledigt") {
                                    job.setzeFertig(!job.istFertig)
                                    try? viewContext.save()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
                
                // -----------------------------------------------------------------
                // GLIED 3: OPERATIVE GEWERKE
                // -----------------------------------------------------------------
                Section(header: Label("Glied 3: Laufende Handwerker", systemImage: "person.2.fill")) {
                    // Handwerker = alles, was NICHT Baustelleneinrichtung ist (sonst
                    // stünde „Baustelle einrichten … absichern" doppelt in Glied 2 und 3).
                    let handwerkJobs = (event.jobs?.allObjects as? [Auftrag] ?? [])
                        .filter { !$0.istBaustelleneinrichtung }
                    
                    if event.baugenehmigungNr?.isEmpty ?? true {
                        Text("🔒 Gesperrt – Wartet auf Glied 1 (Baugenehmigung)")
                            .font(.subheadline).italic().foregroundStyle(.secondary)
                    } else if handwerkJobs.isEmpty {
                        Text("Keine aktiven Handwerker-Aufträge vorhanden.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(handwerkJobs, id: \.objectID) { job in
                            HStack {
                                Circle().fill(job.istFertig ? Color.green : Color.orange).frame(width: 8, height: 8)
                                Text(job.processingDetails ?? "Gewerk").font(.subheadline)
                                Spacer()
                                Text(job.istFertig ? "Abgeschlossen" : "Aktiv").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Kausalbaukette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.tint(.orange)
                }
            }
            .onAppear {
                // Vorbefüllung falls schon eine Nummer im System existiert
                baugenehmigungEingabe = event.baugenehmigungNr ?? ""
            }
        }
    }
    
    // Filtert die Baustelleneinrichtungs-Aufträge — am echten Gewerk + Wortstamm
    // (geteilt mit der Ampel), damit „Baustelle einrichten … absichern" auch trifft.
    private func holeInfrastrukturJobs() -> [Auftrag] {
        let all = event.jobs?.allObjects as? [Auftrag] ?? []
        return all.filter { $0.istBaustelleneinrichtung }
            .sorted { ($0.processingDetails ?? "") < ($1.processingDetails ?? "") }
    }
}
