import SwiftUI

struct AIDetailView: View {
    let productName: String
    let analysis: ClinicalAnalysis?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // TITEL-SEKTION
                headerSection
                
                if let data = analysis {
                    // 1. AMPEL (Wichtigste Info zuerst)
                    trafficLightSection(data: data)
                    
                    // 2. BASIS-DATEN (BE, kcal, Makros)
                    SectionView(title: "Energetische Analyse", icon: "bolt.fill", color: .blue) {
                        VStack(alignment: .leading, spacing: 10) {
                            DetailRow(label: "Broteinheiten (BE)", value: data.beValue)
                            DetailRow(label: "Brennwert", value: "\(data.calories) kcal")
                            DetailRow(label: "Glykämischer Index", value: data.glycemicIndex ?? "k.A.")
                            Divider()
                            HStack {
                                MacroNutrientView(label: "Eiw.", value: data.protein, color: .orange)
                                MacroNutrientView(label: "KH", value: data.carbs, color: .blue)
                                MacroNutrientView(label: "Fett", value: data.fat, color: .yellow)
                            }
                        }
                    }
                    
                    // 3. VITAMINE & MINERALSTOFFE (Hier waren sie versteckt!)
                    SectionView(title: "Mikronährstoffe", icon: "leaf.fill", color: .green) {
                        Text(data.vitamins ?? "Keine spezifischen Mikronährstoffe gelistet.")
                            .font(.subheadline)
                    }
                    
                    // 4. ALLERGENE & ZUSATZSTOFFE (KI-ERKENNUNG)
                    SectionView(title: "Klinische Warnhinweise", icon: "exclamationmark.triangle.fill", color: .red) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(data.medicalNote)
                                .font(.subheadline).bold()
                            
                            // Falls wir Allergene separat im JSON hätten, kämen sie hierhin.
                            // Aktuell stecken sie oft in der 'medicalNote'.
                        }
                    }
                    
                    // 5. QUELLEN (WIKIPEDIA / DGE)
                    if let sources = data.sources {
                        QuellenHubView(begriff: productName, fakten: sources.map { QuellenInfo(quelle: $0.q, aussage: $0.a) })
                    }
                    
                } else {
                    loadingIndicator
                }
            }
            .padding()
        }
        .navigationTitle("KI-Lexikon")
    }

    // MARK: - Sub-Components

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(productName)
                .font(.system(size: 32, weight: .black, design: .rounded))
            Text("DETEILLIERTE KLINISCHE AUSWERTUNG")
                .font(.caption).bold().padding(6)
                .background(Color.purple.opacity(0.1)).foregroundColor(.purple).cornerRadius(5)
        }
    }

    private func trafficLightSection(data: ClinicalAnalysis) -> some View {
        HStack {
            Text("VERZEHR-RADAR:").font(.subheadline).bold()
            Text(data.frequency)
                .font(.headline).padding(.horizontal, 12).padding(.vertical, 6)
                .background(colorForFrequency(data.frequency)).foregroundColor(.white).cornerRadius(8)
        }
    }

    private var loadingIndicator: some View {
        VStack(spacing: 20) {
            ProgressView().scaleEffect(1.5)
            Text("Analysiere Inhaltsstoffe...").foregroundColor(.secondary)
        }.frame(maxWidth: .infinity, minHeight: 300)
    }

    private func colorForFrequency(_ f: String) -> Color {
        switch f.uppercased() {
        case "IMMER": return .green
        case "OFT": return .blue
        case "SELTEN": return .orange
        case "NIE": return .red
        default: return .gray
        }
    }
}

// MARK: - Hilfs-Views für Makronährstoffe
struct MacroNutrientView: View {
    let label: String
    let value: String
    let color: Color
    var body: some View {
        VStack {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text(value).font(.caption).bold()
                .padding(4).frame(minWidth: 50)
                .background(color.opacity(0.2)).cornerRadius(5)
        }
    }
}
