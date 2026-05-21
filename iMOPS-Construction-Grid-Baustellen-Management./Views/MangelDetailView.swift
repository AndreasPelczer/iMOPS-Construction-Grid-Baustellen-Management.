import SwiftUI
import Combine
import CoreData

struct MangelDetailView: View {
    @Environment(\.managedObjectContext) private var ctx
    @ObservedObject var mangel: Mangel

    @State private var bearbeiten = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statusBanner
                if let pfad = mangel.fotoPfad, let img = UIImage(contentsOfFile: pfad) {
                    fotoCard(img)
                }
                infoCard
                statusAendernCard
                Spacer(minLength: 16)
            }
            .padding()
        }
        .navigationTitle(mangel.titel ?? "Mangel")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Bearbeiten") { bearbeiten = true }
            }
        }
        .sheet(isPresented: $bearbeiten) {
            MangelBearbeitenView(mangel: mangel)
                .environment(\.managedObjectContext, ctx)
        }
    }

    // MARK: - Status-Banner

    private var statusBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: mangel.status.symbol)
                .font(.title2)
                .foregroundStyle(mangel.status.farbe)
            VStack(alignment: .leading, spacing: 2) {
                Text(mangel.status.displayName)
                    .font(.headline)
                    .foregroundStyle(mangel.status.farbe)
                if mangel.istUeberfaellig {
                    Label("Überfällig", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
            Spacer()
            schwereChip
        }
        .padding()
        .background(mangel.status.farbe.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var schwereChip: some View {
        Label(mangel.mangelSchwere.displayName, systemImage: mangel.mangelSchwere.symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(mangel.mangelSchwere.farbe)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(mangel.mangelSchwere.farbe.opacity(0.15))
            .clipShape(Capsule())
    }

    // MARK: - Foto Card

    private func fotoCard(_ img: UIImage) -> some View {
        Image(uiImage: img)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: 240)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let beschr = mangel.beschreibung, !beschr.isEmpty {
                infoZeile(icon: "text.alignleft", label: "Beschreibung", wert: beschr)
                Divider()
            }
            if let ort = mangel.ort, !ort.isEmpty {
                infoZeile(icon: "mappin.and.ellipse", label: "Ort", wert: ort)
                Divider()
            }
            if let gew = mangel.gewerk, !gew.isEmpty {
                infoZeile(icon: "wrench.and.screwdriver", label: "Gewerk", wert: gew)
                Divider()
            }
            if let kg = mangel.kostenGruppeNummer, !kg.isEmpty {
                let bezeichnung = DIN276KostenGruppe.alle.first(where: { $0.nummer == kg })?.bezeichnung ?? ""
                infoZeile(icon: "list.number", label: "Kostengruppe", wert: "\(kg) \(bezeichnung)")
                Divider()
            }
            if let frist = mangel.frist {
                infoZeile(
                    icon: "calendar.badge.clock",
                    label: "Frist",
                    wert: frist.formatted(date: .abbreviated, time: .omitted),
                    farbeWert: mangel.istUeberfaellig ? .red : .primary
                )
                Divider()
            }
            if let von = mangel.erfasstVon, !von.isEmpty {
                infoZeile(icon: "person", label: "Erfasst von", wert: von)
                Divider()
            }
            if let datum = mangel.erfasstAm {
                infoZeile(icon: "clock", label: "Erfasst am", wert: datum.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func infoZeile(icon: String, label: String, wert: String, farbeWert: Color = .primary) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(wert).font(.body).foregroundStyle(farbeWert)
            }
        }
    }

    // MARK: - Status ändern Card

    private var statusAendernCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Status ändern").font(.headline)
            HStack(spacing: 10) {
                ForEach(MangelStatus.allCases) { s in
                    Button {
                        mangel.status = s
                        try? ctx.save()
                        if s == .behoben || s == .abgenommen {
                            NotificationService.shared.cancel(for: mangel)
                        } else {
                            NotificationService.shared.schedule(for: mangel)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: s.symbol)
                                .font(.title3)
                                .foregroundStyle(mangel.status == s ? .white : s.farbe)
                            Text(s.displayName)
                                .font(.caption2)
                                .foregroundStyle(mangel.status == s ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(mangel.status == s ? s.farbe : s.farbe.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Mangel Bearbeiten (Inline-Edit)

struct MangelBearbeitenView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var mangel: Mangel

    @State private var titel: String
    @State private var beschreibung: String
    @State private var ort: String
    @State private var gewerk: String
    @State private var schwere: MangelSchwere
    @State private var status: MangelStatus
    @State private var frist: Date
    @State private var hatFrist: Bool
    @State private var erfasstVon: String

    private let gewerkOptionen = [
        "Rohbau", "Mauerwerk", "Beton", "Elektro", "Sanitär",
        "Heizung", "Lüftung", "Trockenbau", "Fliesen", "Maler",
        "Estrich", "Dachdecker", "Zimmerer", "Schlosser", "Sonstiges"
    ]

    init(mangel: Mangel) {
        self.mangel = mangel
        _titel        = State(initialValue: mangel.titel ?? "")
        _beschreibung = State(initialValue: mangel.beschreibung ?? "")
        _ort          = State(initialValue: mangel.ort ?? "")
        _gewerk       = State(initialValue: mangel.gewerk ?? "")
        _schwere      = State(initialValue: mangel.mangelSchwere)
        _status       = State(initialValue: mangel.status)
        _frist        = State(initialValue: mangel.frist ?? Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date())
        _hatFrist     = State(initialValue: mangel.frist != nil)
        _erfasstVon   = State(initialValue: mangel.erfasstVon ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Mangel") {
                    TextField("Kurztitel", text: $titel)
                    TextField("Details", text: $beschreibung, axis: .vertical).lineLimit(3...6)
                }
                Section("Ort & Gewerk") {
                    TextField("Ort", text: $ort)
                    Picker("Gewerk", selection: $gewerk) {
                        Text("– wählen –").tag("")
                        ForEach(gewerkOptionen, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Schwere & Status") {
                    Picker("Schwere", selection: $schwere) {
                        ForEach(MangelSchwere.allCases) { s in
                            Label(s.displayName, systemImage: s.symbol).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    Picker("Status", selection: $status) {
                        ForEach(MangelStatus.allCases) { s in
                            Label(s.displayName, systemImage: s.symbol).tag(s)
                        }
                    }
                    Toggle("Frist", isOn: $hatFrist)
                    if hatFrist {
                        DatePicker("Frist", selection: $frist, displayedComponents: .date)
                    }
                }
                Section {
                    TextField("Erfasst von", text: $erfasstVon)
                }
            }
            .navigationTitle("Mangel bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { speichern() }
                        .disabled(titel.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func speichern() {
        mangel.titel        = titel.trimmingCharacters(in: .whitespaces)
        mangel.beschreibung = beschreibung.trimmingCharacters(in: .whitespaces)
        mangel.ort          = ort.trimmingCharacters(in: .whitespaces)
        mangel.gewerk       = gewerk
        mangel.mangelSchwere = schwere
        mangel.status       = status
        mangel.frist        = hatFrist ? frist : nil
        mangel.erfasstVon   = erfasstVon.trimmingCharacters(in: .whitespaces)
        try? ctx.save()
        if mangel.status == .behoben || mangel.status == .abgenommen {
            NotificationService.shared.cancel(for: mangel)
        } else {
            NotificationService.shared.schedule(for: mangel)
        }
        dismiss()
    }
}
