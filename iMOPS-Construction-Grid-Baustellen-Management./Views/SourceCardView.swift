import SwiftUI

// MARK: - SourceCardView
// Zeigt eine einzelne Wissensquelle vom Mops-Server an.
// Score-Farbcodierung: >=0.9 gruen, 0.7-0.9 gelb, <0.7 grau.
struct SourceCardView: View {
    let source: MopsSource

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Titel + Score-Badge
            HStack(alignment: .top) {
                Text(source.titel)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.primary)

                Spacer()

                // Score als farbcodiertes Badge
                Text(source.scorePercent)
                    .font(.caption2)
                    .bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(scoreColor.opacity(0.2))
                    .foregroundColor(scoreColor)
                    .cornerRadius(6)
            }

            // Chunk-Preview (max 200 Zeichen)
            if let preview = source.chunk_preview, !preview.isEmpty {
                Text(String(preview.prefix(200)))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            // Source-URL als tappbarer Link (nur wenn https://)
            if let urlString = source.source_url, !urlString.isEmpty {
                if urlString.hasPrefix("https://"), let url = URL(string: urlString) {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                            Text(urlString)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .font(.caption2)
                        .foregroundColor(.orange)
                    }
                } else {
                    // Kein HTTPS → nur als Text anzeigen
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                        Text(urlString)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }

    // Score-Farbcodierung: >=0.9 gruen, 0.7-0.9 gelb, <0.7 grau
    private var scoreColor: Color {
        if source.score >= 0.9 { return .green }
        if source.score >= 0.7 { return .yellow }
        return .gray
    }
}
