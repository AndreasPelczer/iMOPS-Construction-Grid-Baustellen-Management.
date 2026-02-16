import SwiftUI

struct ResultDetailView: View {
    var hub: IntelligenceHub

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // 1. DER QUALITÄTS-SNAPSHOT
                if let image = hub.lastCapturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipped()
                        .cornerRadius(15)
                        .shadow(radius: 5)
                }

                // 2. TITEL & STATUS
                HStack {
                    VStack(alignment: .leading) {
                        Text(hub.activeProduct?.name ?? hub.activeLexikon?.name ?? "Analyse")
                            .font(.largeTitle).bold()
                        Text("iMOPS // ChefIQ Modus")
                            .font(.caption).bold().foregroundColor(.orange)
                    }
                    Spacer()
                    Image(systemName: "person.badge.shield.check")
                        .font(.title)
                        .foregroundColor(.green)
                }

                // 3. OPERATIVE SECTION
                VStack(alignment: .leading, spacing: 15) {
                    Label("Operative Anweisungen", systemImage: "chefhat")
                        .font(.headline)

                    HStack {
                        Image(systemName: "thermometer.medium")
                            .foregroundColor(.orange)
                        Text(hub.cookingInstruction.isEmpty ? "Scanne Produkt für Garanalyse..." : hub.cookingInstruction)
                            .font(.body)
                            .bold()
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)

                    // iMOPS Parameter-Cards
                    HStack(spacing: 10) {
                        MUMPSBadge(label: "Mensch", val: iMOPS.GET(.nav("ACTIVE_USER")) ?? "---", icon: "person.fill", color: .blue)
                        MUMPSBadge(label: "Umfeld", val: iMOPS.GET(.nav("LOCATION")) ?? "---", icon: "door.left.hand.closed", color: .purple)
                        MUMPSBadge(label: "Safety", val: "Check OK", icon: "shield.checkpass", color: .green)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(15)

                // 4. BESTANDS-ANALYSE (Klinisch/Wissen)
                VStack(alignment: .leading, spacing: 15) {
                    Label("Analyse-Details", systemImage: "list.bullet.indent")
                        .font(.headline)

                    if let analysis = hub.activeLexikon?.analysis {
                        InfoBlock(title: "Broteinheiten", value: analysis.beValue, icon: "chart.bar", color: .blue)
                        InfoBlock(title: "Wissens-Kern", value: analysis.medicalNote, icon: "brain", color: .red)

                        // Vollständige klinische Analyse
                        AIDetailView(productName: hub.activeLexikon?.name ?? "Produkt", analysis: analysis)
                    }
                }

                // 5. Seubert-Inventar (falls vorhanden)
                if let seubert = hub.activeSeubert {
                    SeubertDetailView(item: seubert)
                }

            }
            .padding()
        }
        .overlay {
            if hub.isLoading {
                LoadingOverlay()
            }
        }
    }
}

// MARK: - Hilfs-Views
struct MUMPSBadge: View {
    let label: String
    let val: String
    let icon: String
    let color: Color

    var body: some View {
        VStack {
            Image(systemName: icon).font(.caption)
            Text(label)
                .font(.system(size: 8, weight: .bold).smallCaps())
            Text(val)
                .font(.system(size: 10, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .foregroundColor(color)
        .cornerRadius(8)
    }
}
