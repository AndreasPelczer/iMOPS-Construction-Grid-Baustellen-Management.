import SwiftUI
import CoreData
import SafariServices

struct ProductKnowledgeDetailView: View {
    @Environment(\.managedObjectContext) private var context
    @ObservedObject var product: CDProduct

    // Edit
    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var editedDescription: String = ""
    @State private var editedAllergene: String = ""

    // Browser
    @State private var activeURL: URL?
    @State private var showBrowser = false

    // MARK: - UI

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                headerSection

                inventoryPanel
                    .padding(.horizontal)

                actionRow
                    .padding(.horizontal)

                if hasSafetyInfo {
                    safetyPanel
                        .padding(.horizontal)
                }

                descriptionCard
                    .padding(.horizontal)

                if !algorithmText.isEmpty {
                    algorithmCard
                        .padding(.horizontal)
                }

                if !ingredientList.isEmpty {
                    ingredientsCard
                        .padding(.horizontal)
                }

                if hasNutrition {
                    nutritionGrid
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(product.name ?? "Produkt")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBrowser) {
            if let url = activeURL { SafariWebView(url: url) }
        }
        .onAppear {
            editedName = product.name ?? ""
            editedDescription = product.beschreibung ?? ""
            editedAllergene = product.allergene ?? ""
        }
    }

    // MARK: - Header (modern)

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text((product.category ?? "INFO").uppercased())
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                    .foregroundStyle(Color.accentColor)

                Spacer()

                Button {
                    if isEditing { saveChanges() } else { startEditing() }
                } label: {
                    Label(isEditing ? "Speichern" : "Bearbeiten", systemImage: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isEditing ? Color.green.opacity(0.22) : Color.blue.opacity(0.12))
                        )
                }
                .foregroundStyle(isEditing ? .green : .blue)
            }

            if isEditing {
                TextField("Name", text: $editedName)
                    .font(.system(size: 28, weight: .bold))
                    .textFieldStyle(.roundedBorder)
            } else {
                Text(product.name ?? "")
                    .font(.system(size: 28, weight: .bold))
                    .lineLimit(2)
            }

            if let source = product.dataSource, !source.isEmpty {
                Text(source)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.20),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Inventory (Lager)

    private var inventoryPanel: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("LAGERBESTAND", systemImage: "snowflake")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                    Spacer()

                    Menu(product.stockUnit ?? "Einheit") {
                        Button("Stk.") { updateUnit("Stk.") }
                        Button("KG") { updateUnit("KG") }
                        Button("Kisten") { updateUnit("Kisten") }
                        Button("Beutel") { updateUnit("Beutel") }
                        Button("Einheiten") { updateUnit("Einheiten") }
                    }
                    .font(.caption.bold())
                }

                HStack(spacing: 18) {
                    Button { adjustStock(by: -1) } label: {
                        Image(systemName: "minus.circle.fill").font(.title2)
                    }
                    .foregroundStyle(.blue)

                    Text(String(format: "%.1f", product.stockQuantity))
                        .font(.title.bold())
                        .frame(minWidth: 70)

                    Button { adjustStock(by: 1) } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                    .foregroundStyle(.blue)

                    Spacer()

                    Text(product.stockUnit ?? "Stk.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 12) {
            actionButton(title: "YouTube", icon: "play.rectangle.fill", tint: .red) {
                openSearch(kind: .youtube)
            }
            actionButton(title: "Wiki", icon: "book.fill", tint: .gray) {
                openSearch(kind: .wiki)
            }
            actionButton(title: "Google", icon: "globe", tint: .blue) {
                openSearch(kind: .google)
            }
        }
    }

    // MARK: - Beschreibung

    private var descriptionCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text("BESCHREIBUNG")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                if isEditing {
                    TextEditor(text: $editedDescription)
                        .frame(minHeight: 140)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Text(product.beschreibung?.isEmpty == false ? (product.beschreibung ?? "") : "Keine Daten.")
                        .font(.body)
                        .lineSpacing(4)
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    // MARK: - Algorithmus

    private var algorithmCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Label("ANWEISUNGEN", systemImage: "list.bullet.rectangle.portrait")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Text(algorithmText)
                    .font(.body.monospaced())
                    .lineSpacing(3)
                    .padding(10)
                    .background(Color.black.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Zutaten / Komponenten

    private var ingredientsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Label("KOMPONENTEN", systemImage: "square.stack.3d.up")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ForEach(ingredientList, id: \.objectID) { ing in
                    HStack {
                        Text(ing.name ?? "")
                        Spacer()
                        Text("\((ing.menge ?? "").trimmingCharacters(in: .whitespaces)) \((ing.einheit ?? "").trimmingCharacters(in: .whitespaces))")
                            .bold()
                            .foregroundStyle(.secondary)
                    }
                    Divider().opacity(0.4)
                }
            }
        }
    }

    // MARK: - Allergene (Warnfarben modern)

    private var safetyPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("ALLERGEN / ZUSATZSTOFF CHECK")
                    .font(.headline.bold())
                Spacer()
            }
            .padding(12)
            .foregroundStyle(.white)
            .background(
                LinearGradient(colors: [Color.red, Color.orange],
                               startPoint: .leading,
                               endPoint: .trailing)
            )

            VStack(alignment: .leading, spacing: 12) {
                if isEditing {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Allergene (Komma-getrennt, z.B. A,G,L)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("A,G,L...", text: $editedAllergene)
                            .textFieldStyle(.roundedBorder)
                    }
                } else if let a = product.allergene, !a.isEmpty {
                    let codes = a.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    ForEach(codes, id: \.self) { code in
                        HStack(alignment: .top, spacing: 10) {
                            Text(code.uppercased())
                                .font(.system(size: 14, weight: .black))
                                .frame(width: 44, height: 30)
                                .background(Color.red.opacity(0.90))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(GastroLegende.explain(code: String(code)).uppercased())
                                    .font(.subheadline.bold())
                                Text("Bitte prüfen / kennzeichnen.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }

                if let z = product.zusatzstoffe, !z.isEmpty {
                    Divider().opacity(0.35)
                    Text("Zusatzstoffe: \(z)")
                        .font(.subheadline)
                }
            }
            .padding(14)
            .background(Color.red.opacity(0.06))
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.red.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Nutrition

    private var nutritionGrid: some View {
        HStack(spacing: 10) {
            nutritionItem(label: "KCAL", value: product.kcal ?? "")
            nutritionItem(label: "FETT", value: product.fett ?? "")
            nutritionItem(label: "ZUCKER", value: product.zucker ?? "")
        }
    }

    private func nutritionItem(label: String, value: String) -> some View {
        card(padding: 10) {
            VStack(spacing: 4) {
                Text(value.isEmpty ? "–" : value)
                    .font(.headline.bold())
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Helpers / Data

    private var ingredientList: [CDIngredient] {
        let set = product.ingredients as? Set<CDIngredient> ?? []
        return set.sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    private var algorithmText: String {
        (product.algorithmusText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasSafetyInfo: Bool {
        let a = (product.allergene ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let z = (product.zusatzstoffe ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !a.isEmpty || !z.isEmpty
    }

    private var hasNutrition: Bool {
        let kcal = (product.kcal ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let fett = (product.fett ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let zucker = (product.zucker ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !kcal.isEmpty || !fett.isEmpty || !zucker.isEmpty
    }

    private func startEditing() {
        editedName = product.name ?? ""
        editedDescription = product.beschreibung ?? ""
        editedAllergene = product.allergene ?? ""
        isEditing = true
    }

    private func saveChanges() {
        product.name = editedName
        product.beschreibung = editedDescription
        product.allergene = editedAllergene.trimmingCharacters(in: .whitespacesAndNewlines)

        do { try context.save() }
        catch { print("Save Fehler: \(error)") }

        isEditing = false
    }

    private func adjustStock(by amount: Double) {
        product.stockQuantity = max(0, product.stockQuantity + amount)
        do { try context.save() } catch { print("🚨 Save Fehler: \(error)") }
    }

    private func updateUnit(_ newUnit: String) {
        product.stockUnit = newUnit
        do { try context.save() } catch { print("🚨 Save Fehler: \(error)") }
    }

    private enum SearchKind { case youtube, wiki, google }

    private func openSearch(kind: SearchKind) {
        let name = (product.name ?? "").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString: String

        switch kind {
        case .youtube: urlString = "https://www.youtube.com/results?search_query=Profi+Kochen+\(name)"
        case .wiki:   urlString = "https://de.wikipedia.org/wiki/\(name)"
        case .google: urlString = "https://www.google.com/search?q=Gastronomie+Warenkunde+\(name)"
        }

        if let url = URL(string: urlString) {
            activeURL = url
            showBrowser = true
        }
    }

    // MARK: - Card style

    private func card<Content: View>(padding: CGFloat = 14, @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(padding)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }

    private func actionButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title.uppercased())
                    .font(.caption2.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(tint.opacity(0.12))
            .foregroundStyle(tint)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Safari

struct SafariWebView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Allergene

enum GastroLegende {
    static let allergene: [String: String] = [
        "a": "Gluten", "b": "Krebstiere", "c": "Eier", "d": "Fisch", "e": "Erdnüsse",
        "f": "Soja", "g": "Milch/Laktose", "h": "Nüsse", "i": "Sellerie", "j": "Senf",
        "k": "Sesam", "l": "Sulfite", "m": "Lupinen", "n": "Weichtiere"
    ]

    static func explain(code: String) -> String {
        allergene[code.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)] ?? "Zusatzstoff"
    }
}
