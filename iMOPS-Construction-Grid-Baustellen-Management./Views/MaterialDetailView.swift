import SwiftUI

struct MaterialDetailView: View {
    @ObservedObject var material: CDLexikonEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(material.code ?? "")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.tint.opacity(0.15))
                            .clipShape(Capsule())
                        Spacer()
                        Text(material.kategorie ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(material.name ?? "")
                        .font(.title2.bold())
                    if let beschr = material.beschreibung, !beschr.isEmpty {
                        Text(beschr)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                if let details = material.details, !details.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Technische Details").font(.headline)
                        Text(details).font(.body)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding()
        }
        .navigationTitle("Material")
        .navigationBarTitleDisplayMode(.inline)
    }
}
