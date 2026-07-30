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

    @State private var direktPreis: String = ""

    var onOpenSourceDocument: ((URL) -> Void)? = nil

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
                    Text("EP:")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField("0,00", text: $direktPreis)
                        .keyboardType(.decimalPad)
                        .frame(width: 70)
                        .textFieldStyle(.roundedBorder)
                        .onAppear {
                            let val = position.value(forKey: "einkaufspreis") as? Double ?? 0
                            if val > 0 {
                                direktPreis = String(format: "%.2f", val)
                                    .replacingOccurrences(of: ".", with: ",")
                            }
                        }
                        .onChange(of: direktPreis) { _, newValue in
                            let cleaned = newValue.replacingOccurrences(of: ",", with: ".")
                            let preis = Double(cleaned) ?? 0.0
                            position.setValue(preis, forKey: "einkaufspreis")
                            try? position.managedObjectContext?.save()
                        }

                    Spacer()

                    let val = position.value(forKey: "einkaufspreis") as? Double ?? 0
                    if val > 0 {
                        Text((position.menge * val).formatted(.currency(code: "EUR")))
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

            ZeilenFortschritt(
                wert: position.displayedFortschritt(
                    manuellerProzent: fortStore.fortschritt(for: positionID)?.prozent
                )
            )
        }
        .padding(.vertical, 2)
        .opacity(isAlt ? 0.85 : 1.0)
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
