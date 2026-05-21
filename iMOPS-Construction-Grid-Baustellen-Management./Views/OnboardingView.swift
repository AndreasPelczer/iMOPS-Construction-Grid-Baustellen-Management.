import SwiftUI
import Combine

// MARK: - Onboarding Page Model

private struct OnboardingPage: Identifiable {
    let id: Int
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let bullets: [String]
}

private let pages: [OnboardingPage] = [
    OnboardingPage(
        id: 0,
        icon: "building.2.crop.circle.fill",
        iconColor: .orange,
        title: "Willkommen bei iMOPS",
        subtitle: "Baustellen-Management für Profis",
        bullets: [
            "Alle Projekte, Aufträge und Pläne auf einen Blick",
            "Daten bleiben lokal auf deinem Gerät",
            "Keine Abo-Falle — deine App, deine Daten"
        ]
    ),
    OnboardingPage(
        id: 1,
        icon: "doc.text.fill",
        iconColor: .orange,
        title: "Leistungsverzeichnis",
        subtitle: "LV anlegen, importieren, exportieren",
        bullets: [
            "Positionen manuell anlegen oder aus PDF importieren",
            "DIN 276 Kostengruppen-Struktur automatisch",
            "Angebotsvergleich: EP/GP von Scharpegge, Hauff & Co.",
            "Preisanfrage-Mail pro Lieferant mit einem Tipp"
        ]
    ),
    OnboardingPage(
        id: 2,
        icon: "exclamationmark.triangle.fill",
        iconColor: .red,
        title: "Mängel & Qualität",
        subtitle: "Vor Ort erfassen, nie wieder vergessen",
        bullets: [
            "Mängel mit Foto, Kategorie und Status erfassen",
            "Spracheingabe: Beschreibung einfach diktieren",
            "Status-Tracking: Offen → In Arbeit → Erledigt",
            "Bautagesbericht als PDF mit einem Tipp erzeugen"
        ]
    ),
    OnboardingPage(
        id: 3,
        icon: "books.vertical.fill",
        iconColor: .brown,
        title: "Material-Katalog",
        subtitle: "Scharpegge-Sortiment direkt in der App",
        bullets: [
            "Vollständiger Scharpegge-Katalog integriert",
            "Materialien Baustellen zuweisen",
            "Art.-Nr. direkt ins LV übernehmen",
            "Weitere Lieferanten jederzeit ergänzbar"
        ]
    ),
    OnboardingPage(
        id: 4,
        icon: "brain.head.profile",
        iconColor: .purple,
        title: "BuildIQ & Mehr",
        subtitle: "KI-Scanner, CAD-Viewer, Wetter",
        bullets: [
            "BuildIQ: Fotos analysieren und Materialmengen schätzen",
            "3D-Pläne direkt in der App betrachten (USDZ, OBJ)",
            "Wetter-Karte mit Bau-Ampel für jeden Standort",
            "Crew-Planung und Mitarbeiter-Übersicht"
        ]
    )
]

// MARK: - Onboarding View

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompleted = false
    @State private var currentPage = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(pages) { page in
                    pageView(page)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .top)

            // Bottom controls
            VStack(spacing: 20) {
                // Page dots
                HStack(spacing: 8) {
                    ForEach(pages) { page in
                        Capsule()
                            .fill(currentPage == page.id ? Color.orange : Color.secondary.opacity(0.4))
                            .frame(width: currentPage == page.id ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }

                // Action button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        hasCompleted = true
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Weiter" : "Los geht’s")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 24)

                // Skip
                if currentPage < pages.count - 1 {
                    Button("Überspringen") {
                        hasCompleted = true
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 40)
            .background(
                LinearGradient(
                    colors: [.clear, Color(.systemBackground).opacity(0.95), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
    }

    // MARK: - Page View

    private func pageView(_ page: OnboardingPage) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Icon hero
                ZStack {
                    Circle()
                        .fill(page.iconColor.opacity(0.12))
                        .frame(width: 160, height: 160)
                    Image(systemName: page.icon)
                        .font(.system(size: 72))
                        .foregroundStyle(page.iconColor)
                }
                .padding(.top, 80)
                .padding(.bottom, 32)

                // Title
                VStack(spacing: 8) {
                    Text(page.title)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text(page.subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                // Bullets
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(page.bullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(page.iconColor)
                                .font(.body)
                                .padding(.top, 1)
                            Text(bullet)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(24)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 24)
                .padding(.top, 32)

                Spacer(minLength: 200)
            }
        }
    }
}
