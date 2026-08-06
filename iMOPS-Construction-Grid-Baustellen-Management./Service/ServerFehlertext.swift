import Foundation

/// Übersetzt eine unlesbare Antwort des Mops-Servers in einen Satz, der auf der
/// Baustelle weiterhilft — für alle Views, die Dateien hochladen.
///
/// **Nie den rohen Antwort-Body anzeigen.** Steht der Mops gerade im Neustart, antwortet
/// nicht er, sondern Cloudflare — mit einer kompletten HTML-Fehlerseite. Die landete früher
/// ungefiltert im Fehlerfeld und sah aus wie ein kaputtes CSV, obwohl Datei UND Server in
/// Ordnung waren (04.08.26: 502 um 15:14:53 UTC, eine Sekunde vor „startup complete";
/// derselbe Upload lief Minuten später fehlerfrei durch).
///
/// Das Startfenster ist kein Ausrutscher, sondern Bauart: der Server lädt beim Hochfahren
/// ein Embedding-Modell und ist dabei rund elf Sekunden lang nicht ansprechbar. Wer in
/// dieses Loch drückt, bekommt zwangsläufig einen 502 — und soll das verstehen können.
enum ServerFehlertext {

    static func fuer(status: Int, data: Data) -> String {
        // Eigene Fehler schickt der Mops als {"detail": "..."} — das ist die beste Auskunft,
        // präziser als jeder Text, den wir hier erfinden könnten.
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let detail = obj["detail"] as? String, !detail.isEmpty {
            return detail
        }

        switch status {
        case 502, 503, 504:
            return neustartHinweis
        case 413:
            return "Die Datei ist zu groß für den Server."
        case 401, 403:
            return "Keine Berechtigung für den Mops-Server."
        case 404:
            return "Der Server kennt diese Adresse nicht.\nLäuft dort die aktuelle Mops-Version?"
        default:
            // Auch mit Status 200 kann eine Fehlerseite kommen (Proxy, Portal, Tunnel-Panne),
            // dann rettet der Statuscode nicht — nur der Blick in den Body.
            if siehtNachFehlerseiteAus(data) { return neustartHinweis }

            if status == 0 || (200...299).contains(status) {
                return "Die Antwort vom Server war unerwartet und ließ sich nicht lesen."
            }
            return "Der Server hat mit Status \(status) geantwortet.\nDie Antwort ließ sich nicht lesen."
        }
    }

    /// Der letzte Satz ist Absicht: „liegt es an meiner Datei?" ist die erste Frage,
    /// die sich draußen stellt — und sie hat schon einmal eine Stunde Suche gekostet.
    static let neustartHinweis =
        "Der Mops-Server ist gerade nicht erreichbar — er startet vermutlich neu "
        + "(das dauert etwa eine Minute).\nBitte gleich noch einmal versuchen. "
        + "An der Datei liegt es nicht."

    private static func siehtNachFehlerseiteAus(_ data: Data) -> Bool {
        guard let roh = String(data: data, encoding: .utf8) else { return false }
        let beginn = roh.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200).lowercased()
        return beginn.hasPrefix("<") || beginn.contains("<html") || beginn.contains("<!doctype")
    }
}
