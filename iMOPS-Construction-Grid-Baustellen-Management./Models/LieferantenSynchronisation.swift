import Foundation

// MARK: - Lokale Lieferanten-Synchronisation

/// Offline-first Anfrageobjekt fuer Materialbedarf.
///
/// Es enthaelt nur lokale Referenzen und text-/JSON-faehige Daten. KI kann beim
/// Befuellen helfen, aber der Zustand und die Warnlogik sind deterministisch.
struct UniversalAnfrage: Codable, Equatable, Identifiable {
    var id: UUID
    var baustelleId: String
    var status: Lieferstatus
    var positionen: [BedarfsPosition]
    var lieferung: LieferDetails

    init(
        id: UUID = UUID(),
        baustelleId: String,
        status: Lieferstatus = .bedarfErkannt,
        positionen: [BedarfsPosition] = [],
        lieferung: LieferDetails
    ) {
        self.id = id
        self.baustelleId = baustelleId
        self.status = status
        self.positionen = positionen
        self.lieferung = lieferung
    }
}

struct BedarfsPosition: Codable, Equatable, Identifiable {
    var id: UUID
    var lvPositionId: String?
    var posNr: String
    var material: String
    var menge: Double
    var einheit: String
    var bedarfsquelle: BedarfsQuelle

    init(
        id: UUID = UUID(),
        lvPositionId: String? = nil,
        posNr: String,
        material: String,
        menge: Double,
        einheit: String,
        bedarfsquelle: BedarfsQuelle
    ) {
        self.id = id
        self.lvPositionId = lvPositionId
        self.posNr = posNr
        self.material = material
        self.menge = menge
        self.einheit = einheit
        self.bedarfsquelle = bedarfsquelle
    }
}

struct BedarfsQuelle: Codable, Equatable {
    var typ: BedarfsQuelleTyp
    var ref: String
    var datei: String?
    var planblatt: String?
    var notiz: String?
    var geprueftVon: String?

    var istNachweisbar: Bool {
        !ref.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum BedarfsQuelleTyp: String, Codable, CaseIterable {
    case lv
    case plan
    case foto
    case polier
    case unbekannt
}

struct LieferDetails: Codable, Equatable {
    var beauftragtAm: Date?
    var lieferfensterVon: Date
    var lieferfensterBis: Date
    var bestaetigtAm: Date?
    var warnschwelleStunden: Double

    init(
        beauftragtAm: Date? = nil,
        lieferfensterVon: Date,
        lieferfensterBis: Date,
        bestaetigtAm: Date? = nil,
        warnschwelleStunden: Double = 48
    ) {
        self.beauftragtAm = beauftragtAm
        self.lieferfensterVon = lieferfensterVon
        self.lieferfensterBis = lieferfensterBis
        self.bestaetigtAm = bestaetigtAm
        self.warnschwelleStunden = warnschwelleStunden
    }
}

enum Lieferstatus: String, Codable, CaseIterable {
    case bedarfErkannt
    case bedarfBestaetigt
    case angefragt
    case angebotErhalten
    case beauftragt
    case lieferungBestaetigt
    case geliefert
    case abgeschlossen
}

enum WarnStufe: String, Codable, Equatable {
    case keine
    case lieferungUnbestaetigt
    case terminKritisch
}

struct LieferantenErfahrung: Codable, Equatable {
    var staerken: [String]
    var schwaechen: [String]
    var einschraenkungen: [String]
    var zuverlaessigkeit: Double

    init(
        staerken: [String] = [],
        schwaechen: [String] = [],
        einschraenkungen: [String] = [],
        zuverlaessigkeit: Double = 0
    ) {
        self.staerken = staerken
        self.schwaechen = schwaechen
        self.einschraenkungen = einschraenkungen
        self.zuverlaessigkeit = min(max(zuverlaessigkeit, 0), 1)
    }
}

extension UniversalAnfrage {
    var aktuelleWarnstufe: WarnStufe {
        warnstufe(now: Date())
    }

    func warnstufe(now: Date) -> WarnStufe {
        guard status == .beauftragt else { return .keine }
        guard lieferung.bestaetigtAm == nil else { return .keine }

        if now > lieferung.lieferfensterBis {
            return .terminKritisch
        }

        let warnschwelle = lieferung.warnschwelleStunden * 3_600
        let restzeit = lieferung.lieferfensterVon.timeIntervalSince(now)
        return restzeit <= warnschwelle ? .lieferungUnbestaetigt : .keine
    }
}
