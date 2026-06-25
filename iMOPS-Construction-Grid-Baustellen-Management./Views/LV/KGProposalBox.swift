import SwiftUI

struct KGProposalBox: View {
    let proposal: KGProposal
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label("Fachvorschlag", systemImage: "checkmark.shield")
                    .font(.subheadline.bold())
                Spacer()
                Text("KG \(proposal.suggestedKG)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.orange)
            }

            Text("Sicherheit \(proposal.confidence.formatted(.percent.precision(.fractionLength(0))))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(proposal.begruendung)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                onApply()
            } label: {
                Label("Vorschlag übernehmen", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding(.vertical, 6)
    }
}
