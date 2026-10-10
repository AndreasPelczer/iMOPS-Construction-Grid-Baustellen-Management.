//
//  Abwesenheiten.swift
//  Wer wann nicht da ist (10.10.2026) – Urlaub oder „abwesend", nie ein Grund.
//
//  Andreas: „Urlaubsplanung und Mitarbeiter im Blick". Bisher gab es dafür nichts:
//  `Employee` kennt nur Name, Rolle, Telefon, PIN. Damit kein Core-Data-Umbau nötig ist,
//  liegt die Liste als JSON (Muster wie `LagerStore`). Der Schlüssel zum Mitarbeiter ist
//  der NAME – genau wie `Auftrag.employeeName`, sonst fände der Wochenblick sie nicht.
//
//  🔒 „krank" ist eine Gesundheitsangabe. Es gibt nur `urlaub` und `abwesend` – kein Grund,
//  kein Freitext. Die Liste geht als Ganzes an die Box (`/abwesenheiten/stand`), damit
//  Jarvis „im Urlaub, aber eingeteilt" sagen kann.
//

import Foundation
import Combine
import os

private let logger = Logger(subsystem: "com.deadrabbit.imops", category: "Abwesenheiten")

struct Abwesenheit: Codable, Identifiable, Equatable {
    enum Art: String, Codable, CaseIterable, Identifiable {
        case urlaub, abwesend
        var id: String { rawValue }
        var anzeige: String { self == .urlaub ? "Urlaub" : "abwesend" }
    }
    var id = UUID()
    var name: String
    var von: Date
    var bis: Date
    var art: Art = .urlaub

    /// „20.10.–24.10.2026"
    var zeitraum: String {
        let kurz = Date.FormatStyle().day(.twoDigits).month(.twoDigits)
        return "\(von.formatted(kurz))–\(bis.formatted(date: .numeric, time: .omitted))"
    }
}

final class AbwesenheitenStore: ObservableObject {
    static let shared = AbwesenheitenStore()

    @Published private(set) var eintraege: [Abwesenheit] = []
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("abwesenheiten.json")
        if let d = try? Data(contentsOf: self.fileURL), let l = try? JSONDecoder().decode([Abwesenheit].self, from: d) {
            eintraege = l
        }
    }

    func von(_ name: String) -> [Abwesenheit] {
        eintraege.filter { $0.name.caseInsensitiveCompare(name) == .orderedSame }.sorted { $0.von < $1.von }
    }

    /// Doppelt eingetragen (gleiche Person, gleicher Zeitraum) wird nicht doppelt gespeichert –
    /// derselbe Jarvis-Entwurf zweimal übernommen bleibt ein Eintrag.
    func hinzu(_ a: Abwesenheit) {
        let cal = Calendar.current
        guard !eintraege.contains(where: { $0.name.caseInsensitiveCompare(a.name) == .orderedSame
            && cal.isDate($0.von, inSameDayAs: a.von) && cal.isDate($0.bis, inSameDayAs: a.bis) }) else { return }
        eintraege.append(a)
        speichern()
    }

    func entferne(_ a: Abwesenheit) {
        eintraege.removeAll { $0.id == a.id }
        speichern()
    }

    private func speichern() {
        do { try JSONEncoder().encode(eintraege).write(to: fileURL, options: .atomic) }
        catch { logger.error("Abwesenheiten nicht gespeichert: \(error.localizedDescription, privacy: .public)") }
        Task { await melde() }
    }

    // MARK: - An die Box (leise, nur mit Mops-Schlüssel)

    /// Was gemeldet wird – reine Werte, testbar. Datum als yyyy-MM-dd.
    func meldung() -> Data? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let liste = eintraege.map { ["name": $0.name, "von": f.string(from: $0.von), "bis": f.string(from: $0.bis), "art": $0.art.rawValue] }
        return try? JSONSerialization.data(withJSONObject: ["eintraege": liste, "von": "iMOPS-App"])
    }

    func melde() async {
        let schluessel = UserDefaults.standard.string(forKey: BaustellenMeldung.schluesselKey) ?? ""
        guard !schluessel.isEmpty, let url = URL(string: MopsConfig.host + "/abwesenheiten/stand"), let body = meldung() else { return }
        var r = URLRequest(url: url, timeoutInterval: 15)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue(schluessel, forHTTPHeaderField: "X-Mops-Schluessel")
        r.httpBody = body
        do {
            let (_, antwort) = try await URLSession.shared.data(for: r)
            let code = (antwort as? HTTPURLResponse)?.statusCode ?? 0
            if code != 200 { logger.warning("Abwesenheiten: HTTP \(code)") }
        } catch {
            logger.info("Abwesenheiten nicht angekommen: \(error.localizedDescription, privacy: .public)")
        }
    }
}
