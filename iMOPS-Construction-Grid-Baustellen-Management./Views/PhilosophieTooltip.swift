import SwiftUI

// Schicht B aus Save #45: kleines Buch-Icon, das auf Tap ein 1–2-Satz-Popover zeigt.
// „Aktive Stille mit abrufbarer Substanz" — die App redet nicht, hat aber Antworten
// parat, wenn jemand fragt (Buch Kap 10). Kein modaler Dialog, kein Banner.
struct PhilosophieTooltip: View {
    let buchKapitel: String   // z. B. "Buch Kap 6"
    let text: String          // 1–2 Sätze

    @State private var shown = false

    var body: some View {
        Button { shown.toggle() } label: {
            Image(systemName: "book.fill")
                .foregroundStyle(.secondary)
                .opacity(0.5)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $shown) {
            VStack(alignment: .leading, spacing: 8) {
                Text(text).font(.callout)
                Text(buchKapitel).font(.caption2).foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: 280)
            .presentationCompactAdaptation(.popover)
        }
    }
}
