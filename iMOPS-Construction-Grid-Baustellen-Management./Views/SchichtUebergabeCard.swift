//
//  SchichtUebergabeCard.swift
//  Die Schichtübergabe der ganzen Baustelle in EINEM Akt.
//
//  Ablauf (Andreas 13.9.): MA kommt auf die Baustelle, alles ok → er öffnet seine
//  Aufgaben, liest sie (oder nicht) und quittiert mit EINEM Klick „ich übernehme die
//  Verantwortung für alle Aufgaben". Genau dieser Klick IST die Übergabe (zweiseitig,
//  Buch). Kein Klick je Auftrag — die natürliche Grenze ist der Schichtbeginn.
//  Identität automatisch aus der Anmeldung (Rolle). Foto/Stechuhr sind die natürlichen
//  Marken drumherum und kommen als eigener Schritt dazu.
//

import SwiftUI
import CoreData

struct SchichtUebergabeCard: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(AppSession.self) private var session
    @ObservedObject var event: Event

    @State private var zeigeBefund = false

    private var offeneAuftraege: [Auftrag] { event.offeneAuftraege }
    private var heuteUebernommen: Bool { event.schichtHeuteUebernommen }
    private var uebernommenVon: String? { event.schichtUebernommenVon }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Schichtübergabe", systemImage: "hand.raised.fill").font(.headline)

            if offeneAuftraege.isEmpty {
                Text("Keine offenen Aufgaben auf dieser Baustelle.")
                    .font(.subheadline).foregroundStyle(.secondary)

            } else if heuteUebernommen {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    Text("Verantwortung übernommen\(uebernommenVon.map { " · \($0)" } ?? "") · heute")
                        .font(.subheadline)
                    Spacer()
                }
                // Feierabend: die Verantwortung für alle offenen Aufträge hinlegen.
                Button { abgeben() } label: {
                    Label("Feierabend – Baustelle abgeben", systemImage: "figure.walk.departure")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)

            } else {
                if event.hatBesprocheneUebergabe {
                    // Mündlich geklärt — der Mops ist still, zeigt nur die Spur.
                    Label("Übergabe besprochen — mündlich geklärt.",
                          systemImage: "bubble.left.and.bubble.right")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else if event.hatOffeneUebergabe {
                    // Freundlicher Hinweis + die zweite Wahl. Nichts wird erzwungen.
                    Label("Noch keine Übergabe eingetragen. Eintragen — oder habt ihr's besprochen?",
                          systemImage: "hand.wave")
                        .font(.subheadline).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("\(offeneAuftraege.count) offene Aufgaben. Durchsehen und übernehmen:")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                // Der eine Klick: alle Aufgaben verstanden, ich übernehme die Verantwortung.
                Button { uebernehmen(.ok) } label: {
                    Label("Alle Aufgaben verstanden – ich übernehme die Verantwortung",
                          systemImage: "hand.raised.fill")
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                // Zweite Wahl bei offener Übergabe: mündlich geklärt (nie erzwungen).
                if event.hatOffeneUebergabe {
                    Button { besprochen() } label: {
                        Label("Haben wir besprochen", systemImage: "bubble.left.and.bubble.right")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                }

                // Nicht alles ok? Der Befund-Weg daneben.
                Button { zeigeBefund.toggle() } label: {
                    Label("Nicht alles ok?", systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)

                if zeigeBefund {
                    ForEach([Annahmeergebnis.problem, .gehtNicht]) { erg in
                        Button { uebernehmen(erg) } label: {
                            Label(erg.titel, systemImage: erg.symbol)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Feierabend: legt die Verantwortung für alle offenen Aufträge hin.
    private func abgeben() {
        event.schichtAbgeben(rolle: session.role.title)
        try? ctx.save()
    }

    /// „Haben wir besprochen": klärt die offene Übergabe mündlich (Mops wird still).
    private func besprochen() {
        event.schichtBesprochen(rolle: session.role.title)
        try? ctx.save()
    }

    /// Übernimmt in EINEM Akt die Verantwortung für alle offenen Aufträge der Baustelle.
    private func uebernehmen(_ ergebnis: Annahmeergebnis) {
        event.schichtUebernehmen(rolle: session.role.title, ergebnis: ergebnis)
        try? ctx.save()
        zeigeBefund = false
    }
}
