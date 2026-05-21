import SwiftUI
import Combine

struct MaterialDetailView: View {
    @ObservedObject var material: CDLexikonEntry

    private var lieferant: String? {
        guard let kat = material.kategorie else { return nil }
        if kat.hasPrefix("Scharpegge") { return "Scharpegge" }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Kategorie-Badge
                if let kat = material.kategorie, !kat.isEmpty {
                    Text(kat)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }

                // Name + Artikelnummer
                VStack(alignment: .leading, spacing: 6) {
                    Text(material.name ?? "")
                        .font(.title2.bold())
                    if let code = material.code, !code.isEmpty {
                        HStack(spacing: 6) {
                            Text("Art.-Nr.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(code)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.tint.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }

                Divider()

                // Beschreibung
                if let beschr = material.beschreibung, !beschr.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Beschreibung", systemImage: "doc.text")
                            .font(.subheadline.weight(.semibold))
                        Text(beschr)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                // Verpackungseinheit (gebinde)
                if let gebinde = material.details, !gebinde.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Verpackungseinheit", systemImage: "shippingbox")
                            .font(.subheadline.weight(.semibold))
                        Text(gebinde)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                // Lieferant
                if let lief = lieferant {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Lieferant", systemImage: "building.2")
                            .font(.subheadline.weight(.semibold))
                        HStack(spacing: 4) {
                            Text(lief)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.orange)
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding()
        }
        .navigationTitle(material.name ?? "Material")
        .navigationBarTitleDisplayMode(.inline)
    }
}
