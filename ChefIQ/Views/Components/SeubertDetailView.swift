import SwiftUI

/// FENSTER 3: Lager-Detailansicht im neuen "Zusatz-App" Design
struct SeubertDetailView: View {
    // Die Datenquelle bleibt dein SeubertItem
    let item: SeubertItem
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                
                // --- DESIGN AUS ZUSATZ-APP: Das große Hero-Badge ---
                topHeroBadge
                
                VStack(alignment: .leading, spacing: 25) {
                    
                    // TITEL & ARTIKELNUMMER
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.name)
                            .font(.title2.bold())
                        Text("ARTIKELNUMMER: \(item.articleNr) | \(item.supplier)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // --- DESIGN AUS ZUSATZ-APP: Die stilisierte Zubereitungs-Box ---
                    if !item.cookingInstruction.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("ZUBEREITUNG", systemImage: "chefhat.fill")
                                .font(.caption.bold())
                                .foregroundColor(.orange)
                            
                            Text(item.cookingInstruction)
                                .font(.system(.body, design: .serif))
                                .italic()
                                .lineSpacing(4)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    
                    Divider()
                    
                    // ALLERGENE
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Gesetzliche Allergene", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.headline)
                        
                        // Nutzt deine bestehende Allergen-View
                        AllergenBadgeView(allergenCodes: item.allergenCodes)
                    }
                    
                    // ZUSATZSTOFFE
                    if !item.additiveCodes.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Zusatzstoffe", systemImage: "info.circle.fill")
                                .foregroundColor(.blue)
                                .font(.headline)
                            
                            Text(item.additiveCodes)
                                .font(.subheadline)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    // LOGISTIK DATEN (Kategorie etc.)
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Lager-Logistik", systemImage: "shippingbox.fill")
                            .foregroundColor(.secondary)
                            .font(.caption.bold())
                        
                        // Diese beiden Zeilen haben den Fehler verursacht:
                        DetailRow(label: "Kategorie", value: item.category)
                        DetailRow(label: "Lieferant", value: item.supplier)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Sub-Elemente
    
    private var topHeroBadge: some View {
        VStack(spacing: 15) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.white)
            
            Text(item.category.uppercased())
                .font(.caption.bold())
                .tracking(2)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 35)
        .background(
            LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedCorner(radius: 30, corners: [.bottomLeft, .bottomRight]))
        .shadow(radius: 10)
    }
}

// MARK: - Hilfs-Views (Wichtig, damit kein "Cannot find in scope" Fehler kommt!)

/// Zeigt eine Zeile mit Label links und Wert rechts
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).bold()
        }
        .font(.subheadline)
    }
}

/// Hilfskonstruktion für abgerundete Ecken (nur unten am Banner)
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
