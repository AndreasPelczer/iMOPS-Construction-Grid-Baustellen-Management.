//
//  KernelGuardStatusView.swift
//  iMOPS Construction Grid
//
//  Spike-UI für den iMOPS-Kernel (BourdainGuard + MenschMeier + Privacy Shield).
//  Zeigt den aktuellen GuardReport als Banner — typischerweise oben in
//  CrewPlanningView eingebunden.
//
//  Architektur: liest TheBrain.shared aus, evaluiert KernelGuards alle 60s.
//  Bei Whisper-Message (z.B. nach 8h Schicht): prominent in orange/rot.
//

import SwiftUI

@available(iOS 17.0, *)
struct KernelGuardStatusView: View {
    @State private var report: GuardReport?
    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let report = report {
                content(report)
            } else {
                loadingState
            }
        }
        .padding()
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onAppear {
            refresh()
            // Alle 60s neu evaluieren — Fatigue ändert sich nicht in Sekundentakt
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                refresh()
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ report: GuardReport) -> some View {
        // Header
        HStack(spacing: 10) {
            Image(systemName: report.fatigueLevel.sfSymbol)
                .font(.title3)
                .foregroundStyle(fatigueColor(report.fatigueLevel))
            Text("Crew-Schutz")
                .font(.subheadline.bold())
            Spacer()
            Image(systemName: report.securityLevel.sfSymbol)
                .foregroundStyle(report.securityLevel.isShieldActive ? .purple : .secondary)
        }

        // Whisper-Message — sichtbar nur wenn aktiv
        if let whisper = report.whisperMessage {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "quote.bubble.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text(whisper)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }

        // Brigade-Load Progress Bar
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Brigade-Last")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(report.brigadeLoad * 100))%")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(loadColor(report.brigadeLoad))
            }
            ProgressView(value: report.brigadeLoad)
                .tint(loadColor(report.brigadeLoad))
        }

        // Status-Zeilen
        HStack(spacing: 14) {
            Label(report.fatigueLevel.rawValue.capitalized, systemImage: report.fatigueLevel.sfSymbol)
                .font(.caption2)
                .foregroundStyle(fatigueColor(report.fatigueLevel))

            if report.forceTrainingMode {
                Label("Training erzwungen", systemImage: "graduationcap.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            if report.privacyShieldActive {
                Label("Privacy aktiv", systemImage: "shield.fill")
                    .font(.caption2)
                    .foregroundStyle(.purple)
            }

            Spacer()
        }
    }

    private var loadingState: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Kernel-Status wird geladen …")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Styling

    private var backgroundColor: Color {
        if let report = report {
            switch report.fatigueLevel {
            case .fresh:   return Color(.tertiarySystemBackground)
            case .warning: return Color.orange.opacity(0.08)
            case .reset:   return Color.red.opacity(0.10)
            }
        }
        return Color(.tertiarySystemBackground)
    }

    private func fatigueColor(_ level: BourdainGuard.FatigueLevel) -> Color {
        switch level {
        case .fresh:   return .green
        case .warning: return .orange
        case .reset:   return .red
        }
    }

    private func loadColor(_ load: Double) -> Color {
        switch load {
        case 0..<0.5:   return .green
        case 0.5..<0.8: return .orange
        default:        return .red
        }
    }

    // MARK: - Refresh

    private func refresh() {
        let shiftStart: Date = TheBrain.shared.get("^SYS.SHIFT_START") ?? Date()
        let securityRaw: String = TheBrain.shared.get("^SYS.SECURITY_LEVEL") ?? "standard"
        let securityLevel = SecurityLevel(rawValue: securityRaw) ?? .standard
        let adminCount: Int = TheBrain.shared.get("^SYS.ADMIN_REQUEST_COUNT") ?? 0

        let schritte = TheBrain.shared.getArbeitsschritte()

        report = KernelGuards.evaluate(
            schritte: schritte,
            securityLevel: securityLevel,
            sessionStart: shiftStart,
            adminRequestCount: adminCount
        )
    }
}
