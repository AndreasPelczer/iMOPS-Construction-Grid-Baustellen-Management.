import SwiftUI
import CoreData

struct DeletePositionConfirm: ViewModifier {
    @Binding var position: LVPosition?
    let onDelete: (LVPosition) -> Void

    func body(content: Content) -> some View {
        content.alert(
            "Position aus dem LV entfernen?",
            isPresented: Binding(
                get: { position != nil },
                set: { if !$0 { position = nil } }
            ),
            presenting: position
        ) { pos in
            Button("Ja, löschen", role: .destructive) {
                onDelete(pos)
                position = nil
            }
            Button("Abbrechen", role: .cancel) { position = nil }
        } message: { pos in
            if let folgen = pos.loeschFolgen {
                Text("\(pos.posNr ?? "") \(pos.bezeichnung ?? "") hat \(folgen). Alle werden mitgelöscht — das lässt sich nicht rückgängig machen.")
            } else {
                Text("\(pos.posNr ?? "") \(pos.bezeichnung ?? "") wird dauerhaft entfernt. Das lässt sich nicht rückgängig machen.")
            }
        }
    }
}

struct LVPositionRow: View {
    @ObservedObject var position: LVPosition
    @StateObject private var store = AngebotsStore.shared
    @StateObject private var fortStore = LVFortschrittStore.shared

    private var positionID: String { position.objectID.uriRepresentation().absoluteString }
    private var isAlt: Bool { LVPositionHelper.isAlternative(position) }

    /// Die „schwächste" (am wenigsten belegte) Herkunft aller Kostenzeilen der Position.
    /// Zeigt in der Liste auf einen Blick, ob hier noch GESCHÄTZTE Zahlen stecken statt
    /// deiner eigenen — und zwar JEDE nicht selbst bestätigte Quelle, nicht nur KI:
    /// Richtwert (blau) · Startwert (orange) · KI geraten (lila). Vorher wurde nur `.ki`
    /// markiert, darum blieb ein Katalog-Richtwert (z. B. der Eisenflechter-Lohn) unsichtbar.
    /// nil = alles dein Wert/Firmenwert (oder leer) → kein Schätz-Hinweis nötig.
    private var schwaechsteQuelle: Kostenquelle? {
        let quellen = position.materialArray.map { Kostenquelle($0.quelle) }
            + position.lohnArray.map { Kostenquelle($0.quelle) }
            + position.geraeteArray.map { Kostenquelle($0.quelle) }
        func rang(_ q: Kostenquelle) -> Int {
            switch q {
            case .ki:               return 4   // geraten, keine Quelle → unbedingt prüfen
            case .startwert:        return 3   // Platzhalter
            case .praxis, .katalog: return 2   // geliehener Richtwert, nicht deiner
            default:                return 0   // eigen/raffi/unbekannt → kein Schätz-Hinweis
            }
        }
        return quellen.filter { rang($0) > 0 }.max { rang($0) < rang($1) }
    }

    var onOpenSourceDocument: ((URL) -> Void)? = nil

    // Mac: Maus über der Zeile → sofort sichtbar, welche Position unter dem Zeiger ist.
    // Auf dem iPad ohne Zeiger passiert nichts (onHover feuert dort nicht).
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if isAlt {
                    Text("ALT")
                        .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.blue).clipShape(Capsule())
                }
                Text(position.posNr ?? "–")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(isAlt ? .blue : .secondary)
                    .frame(width: isAlt ? nil : 52, alignment: .leading)
                Text(position.bezeichnung ?? "–")
                    .font(.body).lineLimit(2)
                    .foregroundStyle(isAlt ? .secondary : .primary)

                if let q = schwaechsteQuelle {
                    // Gleiches Herkunfts-Badge wie in der Tiefenkalk — eine Sprache in
                    // Liste und Detail. Zeigt die schwächste Quelle der Position.
                    QuelleBadge(quelle: q)
                }

                Spacer()

                Text("\(position.menge.formatted(.number.precision(.fractionLength(0...2)))) \(position.einheit ?? "")")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(isAlt ? .secondary : .primary)
            }

            HStack(spacing: 6) {
                if position.istElement {
                    // B-Element: der Preis kommt aus den Bausteinen. Ohne diesen Zweig
                    // stünde in der Zeile gar kein Preis (ein Element hat selbst keine
                    // Tiefenkalkulation).
                    let kalk = LVKalkulator.kalkuliereElement(position)
                    Image(systemName: "square.stack.3d.down.right.fill")
                        .font(.caption2).foregroundStyle(.indigo)
                    Text(kalk.einheitspreisVK, format: .currency(code: "EUR"))
                        .font(.caption.monospacedDigit()).foregroundStyle(.indigo)
                    Text("EP (Element)").font(.caption2).foregroundStyle(.secondary)

                    Spacer()

                    Text(kalk.gesamtpreis.formatted(.currency(code: "EUR")))
                        .font(.caption.weight(.semibold)).foregroundStyle(.indigo)

                } else if position.hatKalkulation {
                    let kalk = LVKalkulator.kalkuliere(position: position)
                    Image(systemName: "function").font(.caption2).foregroundStyle(.indigo)
                    Text(kalk.einheitspreisVK, format: .currency(code: "EUR"))
                        .font(.caption.monospacedDigit()).foregroundStyle(.indigo)
                    Text("EP (Tiefenkalk)").font(.caption2).foregroundStyle(.secondary)

                    Spacer()

                    Text(kalk.gesamtpreis.formatted(.currency(code: "EUR")))
                        .font(.caption.weight(.semibold)).foregroundStyle(.indigo)

                } else if let best = store.guenstigster(for: positionID) {
                    Image(systemName: "tag.fill").font(.caption2).foregroundStyle(.green)
                    Text(best.einzelpreis, format: .currency(code: "EUR"))
                        .font(.caption.monospacedDigit()).foregroundStyle(.green)
                    Text("EP (Angebot)").font(.caption2).foregroundStyle(.secondary)

                    Spacer()

                    Text((position.menge * best.einzelpreis).formatted(.currency(code: "EUR")))
                        .font(.caption.weight(.semibold)).foregroundStyle(.green)

                } else {
                    // EK/Grundpreis — nur Anzeige. Bearbeitet wird er in der Bearbeiten-View
                    // (Wischen → Bearbeiten): EK dort, VK in der Kalkulation — nicht an zwei
                    // Stellen. Ohne EK und ohne Kalkulation steht „—".
                    let ek = position.value(forKey: "einkaufspreis") as? Double ?? 0
                    Image(systemName: "cart").font(.caption2).foregroundStyle(.secondary)
                    Text(ek > 0 ? ek.formatted(.currency(code: "EUR")) : "—")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Text("EK").font(.caption2).foregroundStyle(.secondary)

                    Spacer()

                    if ek > 0 {
                        Text((position.menge * ek).formatted(.currency(code: "EUR")))
                            .font(.caption.weight(.semibold)).foregroundStyle(.gray)
                    }
                }
            }

            if let docName = position.value(forKey: "dokuName") as? String, !docName.isEmpty {
                HStack {
                    Button {
                        if let pathString = position.value(forKey: "dokuPath") as? String,
                           let url = URL(string: pathString) {
                            onOpenSourceDocument?(url)
                        } else {
                            let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                            let fallbackURL = docsDir.appendingPathComponent("CADFiles").appendingPathComponent(docName)
                            onOpenSourceDocument?(fallbackURL)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text(docName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.12))
                        .foregroundStyle(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.borderless)
                    Spacer()
                }
                .padding(.top, 2)
            } else if let q = position.quellDatei, !q.isEmpty {
                // Herkunft aus dem Plan (Wand-Leser): nur Text, keine Lupe (Plan-Ansicht folgt separat).
                HStack(spacing: 4) {
                    Image(systemName: "ruler")
                    Text(q).lineLimit(1).truncationMode(.middle)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }

            // Der volle LV-Langtext — klappbar. Auf der Baustelle die ganze
            // Leistungsbeschreibung (Tiefe/Boden/Verbau/Umfang) nachlesen.
            if let lt = position.langtext?.trimmingCharacters(in: .whitespacesAndNewlines),
               !lt.isEmpty, lt != (position.bezeichnung ?? "") {
                DisclosureGroup("📄 Langtext") {
                    Text(lt)
                        .font(.caption2).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }
                .font(.caption2).tint(.secondary)
            }

            ZeilenFortschritt(
                wert: position.displayedFortschritt(
                    manuellerProzent: fortStore.fortschritt(for: positionID)?.prozent
                )
            )
        }
        .padding(.vertical, 2)
        .opacity(isAlt ? 0.85 : 1.0)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.orange.opacity(0.10) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isHovered ? Color.orange.opacity(0.65) : Color.clear, lineWidth: 1.5)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
        }
    }
}

private struct ZeilenFortschritt: View {
    let wert: FortschrittWert

    var body: some View {
        switch wert {
        case .unbestimmt:
            EmptyView()
        case .geschaetzt(let p):
            balken(p, tint: .orange, icon: "pencil")
        case .gemessen(let p):
            balken(p, tint: p >= 100 ? .green : .blue, icon: "ruler")
        }
    }

    @ViewBuilder
    private func balken(_ prozent: Double, tint: Color, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 9)).foregroundStyle(tint)
            ProgressView(value: min(prozent, 100), total: 100)
                .progressViewStyle(.linear).tint(tint)
            Text("\(Int(prozent.rounded())) %")
                .font(.caption2.monospacedDigit()).foregroundStyle(tint)
                .frame(width: 46, alignment: .trailing)
        }
    }
}
