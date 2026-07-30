import Foundation
import CoreData

extension LVPosition {

    @nonobjc class func fetchRequest() -> NSFetchRequest<LVPosition> {
        return NSFetchRequest<LVPosition>(entityName: "LVPosition")
    }
    @NSManaged public var quellDatei: String?
    @NSManaged var posNr: String?
    @NSManaged var bezeichnung: String?
    @NSManaged var menge: Double
    @NSManaged var einheit: String?
    @NSManaged var kostenGruppeNummer: String?
    @NSManaged var artikelNummer: String?
    @NSManaged var lieferant: String?
    @NSManaged var wagnisGewinnProzent: Double
    @NSManaged var bgkProzent: Double

    // MARK: - Zuschlag je Kostenart
    // Ein Bauunternehmen schlägt nicht auf alles gleich auf: der Lohn trägt den
    // Löwenanteil von Gemeinkosten und Gewinn, Material und Gerät kaum etwas.
    // Typisch sind Faktoren wie Lohn ×2,75, Material ×1,15, Gerät ×1,10.
    //
    // `zuschlagJeKostenart == false` (Vorgabe) = alles Bisherige: EIN Satz für W&G
    // und EINER für BGK, beide auf die Summe. Ist der Schalter an, gilt je Kostenart
    // ein eigener Satz und W&G/BGK werden nicht mehr gerechnet.
    //
    // Die drei Sätze starten bei 0,20 — genau die Summe der bisherigen Vorgaben
    // (0,12 BGK + 0,08 W&G). Der Schalter allein ändert also KEINE Zahl; erst wer
    // an einem Regler dreht, verändert den Preis.
    // `zuschlagEigen == false` (Vorgabe): die Position rechnet mit den FIRMENWERTEN
    // (FirmenSettings). Ein Satz wird dann an einer Stelle gepflegt statt in jeder
    // Position. Erst wer bewusst abweicht, setzt das Flag — dann gelten die vier
    // Felder unten.
    @NSManaged var zuschlagEigen: Bool
    @NSManaged var zuschlagJeKostenart: Bool
    @NSManaged var zuschlagLohnProzent: Double
    @NSManaged var zuschlagMaterialProzent: Double
    @NSManaged var zuschlagGeraetProzent: Double
    @NSManaged var mengenQuelleRaw: String?
    @NSManaged var event: Event?
    // Welle 9 — Bau-Hierarchie: Position hängt (zusätzlich zu event) an einem Geschoss.
    // Relation + Inverse (Geschoss.lvPositionen) sind im Modell schon definiert; hier nur
    // der getypte Accessor freigelegt (bisher nur per KVC in HierarchieMigration gesetzt).
    @NSManaged var geschoss: Geschoss?

    // Kalkulations-Relationships
    @NSManaged var kalkMaterialien: NSSet?
    @NSManaged var kalkLohn: NSSet?
    @NSManaged var kalkGeraete: NSSet?

    // Aufmasse (Welle 5.1 — echte Messungen gegen die Soll-Menge)
    @NSManaged var aufmasse: NSSet?

    // MARK: - Deckel / Unterpunkte (Typ B — „ein PDF = ein gedeckelter LV-Eintrag")
    // Selbst-Beziehung: ein Deckel bündelt seine Bestandteile als Unterpunkte.
    // REB-23.003-Logik: nur der Deckel zählt in Summen, Unterpunkte sind Beleg (Hilfswert).
    @NSManaged var deckel: LVPosition?            // der Deckel, unter dem diese Position hängt (nil = eigenständig)
    @NSManaged var unterPositionen: NSSet?        // die Belege unter diesem Deckel
    @NSManaged var deckelNotiz: String?           // „warum zusammengeführt" (Prüfstempel)

    // MARK: - Element-Kalkulation (B-Element)
    // Ein Deckel kann ZWEI verschiedene Dinge sein. `deckelArt` unterscheidet sie:
    //
    //   Mengenträger (Vorgabe, alles Bisherige):  der Deckel trägt die Menge selbst,
    //     die Unterpunkte sind Beleg. So kommen Excel-/Bestelllisten-Importe rein.
    //
    //   Element:  der Deckel ist die Summe seiner Bausteine. Jeder Baustein trägt einen
    //     Aufwand JE ELEMENT-EINHEIT (`mengeJeDeckelEinheit`) — „0,35 m³ Schotter je m²
    //     Pflaster". Dadurch kürzen sich die Einheiten heraus und am Element steht ein
    //     Einheitspreis (87 €/m²), egal in welchen Einheiten die Bausteine rechnen.
    //     Der Zuschlag (BGK/W&G) kommt EINMAL oben am Element drauf, nicht je Baustein.
    //
    // Beide Felder sind additiv und optional — bestehende Positionen verhalten sich
    // unverändert (deckelArt == nil ⇒ Mengenträger).
    @NSManaged var deckelArt: String?             // nil/"mengentraeger" | "element"
    @NSManaged var mengeJeDeckelEinheit: Double   // Rezept-Maß des Bausteins, je Einheit des Elements

    // Weg B — Herkunft: Seite im Quell-PDF (1-basiert), aus der Extraktion. nil = unbekannt.
    @NSManaged var seite: NSNumber?
    /// Seitenzahl (1-basiert) im Quell-PDF, falls bekannt.
    var seiteImPDF: Int? { seite?.intValue }

    // MARK: - Mengen-Quelle (gemessen/geschätzt — Welle-9-Fundament)
    // Mirror des KalkMaterial-Musters: roher String in Core Data, getypter Enum-Zugriff.
    var mengenQuelle: MengenQuelle {
        get { MengenQuelle(rawValue: mengenQuelleRaw ?? "manuell") ?? .manuell }
        set { mengenQuelleRaw = newValue.rawValue }
    }

    // Ist die Menge ein Schätz-/Planwert (noch nicht belastbar gemessen)?
    var istGeschaetzt: Bool { mengenQuelle.istGeschaetzt }
}

// MARK: - Typed Accessors

extension LVPosition {

    var materialArray: [PositionMaterial] {
        (kalkMaterialien as? Set<PositionMaterial>)?.sorted { ($0.materialName ?? "") < ($1.materialName ?? "") } ?? []
    }

    var lohnArray: [PositionLohn] {
        (kalkLohn as? Set<PositionLohn>)?.sorted { ($0.qualifikation ?? "") < ($1.qualifikation ?? "") } ?? []
    }

    var geraeteArray: [PositionGeraet] {
        (kalkGeraete as? Set<PositionGeraet>)?.sorted { ($0.geraetName ?? "") < ($1.geraetName ?? "") } ?? []
    }

    // MARK: - Deckel / Unterpunkte

    /// Die Unterpunkte dieses Deckels, stabil sortiert (Bezeichnung, dann posNr).
    var unterPositionenArray: [LVPosition] {
        (unterPositionen as? Set<LVPosition>)?.sorted {
            ($0.bezeichnung ?? "", $0.posNr ?? "") < ($1.bezeichnung ?? "", $1.posNr ?? "")
        } ?? []
    }

    /// Position hängt als Beleg unter einem Deckel → zählt NICHT in Summen.
    var istUnterpunkt: Bool { deckel != nil }

    /// Position ist ein Deckel (hat mind. einen Unterpunkt).
    var istDeckel: Bool { (unterPositionen?.count ?? 0) > 0 }

    // MARK: - Element-Kalkulation (B-Element)

    /// Getypter Zugriff auf `deckelArt` — Muster wie bei `mengenQuelle`.
    var deckelTyp: DeckelArt {
        get { DeckelArt(rawValue: deckelArt ?? "") ?? .mengentraeger }
        set { deckelArt = newValue.rawValue }
    }

    /// Deckel, der seine Bausteine aufsummiert (B-Element).
    /// Braucht Kinder — ein leer markierter Deckel rechnet nichts.
    var istElement: Bool { istDeckel && deckelTyp == .element }

    /// Position ist ein Baustein unter einem Element (A-Element).
    var istElementBaustein: Bool { deckel?.istElement == true }

    // MARK: - Wirksame Zuschlagssätze (Firmenwert oder eigener)
    //
    // Immer diese sechs benutzen, nie die rohen Felder — sonst rechnet der eine
    // Aufrufer mit dem Firmenwert und der nächste mit dem gespeicherten. Genau so
    // sind heute schon zwei Kataloge und fünf KG-Namen auseinandergelaufen.

    /// Rechnet diese Position mit getrennten Sätzen je Kostenart?
    var rechnetJeKostenart: Bool {
        zuschlagEigen ? zuschlagJeKostenart : FirmenSettings.zuschlagJeKostenart
    }

    var satzLohn: Double     { zuschlagEigen ? zuschlagLohnProzent     : FirmenSettings.zuschlagLohn }
    var satzMaterial: Double { zuschlagEigen ? zuschlagMaterialProzent : FirmenSettings.zuschlagMaterial }
    var satzGeraet: Double   { zuschlagEigen ? zuschlagGeraetProzent   : FirmenSettings.zuschlagGeraet }
    var satzBGK: Double      { zuschlagEigen ? bgkProzent              : FirmenSettings.bgk }
    var satzWagnisGewinn: Double {
        zuschlagEigen ? wagnisGewinnProzent : FirmenSettings.wagnisGewinn
    }

    /// Übernimmt die aktuellen Firmenwerte in die eigenen Felder — damit beim
    /// Umschalten auf „abweichen" nicht plötzlich andere Zahlen dastehen als eben
    /// noch angezeigt.
    func uebernehmeFirmenwerte() {
        zuschlagJeKostenart = FirmenSettings.zuschlagJeKostenart
        zuschlagLohnProzent = FirmenSettings.zuschlagLohn
        zuschlagMaterialProzent = FirmenSettings.zuschlagMaterial
        zuschlagGeraetProzent = FirmenSettings.zuschlagGeraet
        bgkProzent = FirmenSettings.bgk
        wagnisGewinnProzent = FirmenSettings.wagnisGewinn
    }

    /// Menge, mit der diese Position tatsächlich rechnet.
    ///
    /// Unter einem Element gilt das Rezept: `mengeJeDeckelEinheit × Bezugsmenge des
    /// Elements`. „0,35 m³/m²" bei 100 m² Pflaster ⇒ 35 m³ Schotter. Überall sonst
    /// ist es schlicht `menge` — deshalb ändert sich für bestehende Positionen nichts.
    var effektiveMenge: Double {
        guard let element = deckel, element.istElement else { return menge }
        return mengeJeDeckelEinheit * element.menge
    }

    // Ob fuer diese Position eine Tiefenkalkulation existiert
    var hatKalkulation: Bool {
        !materialArray.isEmpty || !lohnArray.isEmpty || !geraeteArray.isEmpty
    }

    // MARK: - Soll/Ist (Welle 5.1 — Aufmass-Skelett)
    // Alle computed, KEIN persistiertes Summen-Feld auf Vorrat (Buch Kap 12).

    // Aufmasse, neueste zuerst (erstelltAm = Nachweis-Anker, Buch Kap 4).
    var aufmassArray: [Aufmass] {
        (aufmasse as? Set<Aufmass>)?.sorted { ($0.erstelltAm ?? .distantPast) > ($1.erstelltAm ?? .distantPast) } ?? []
    }

    // Soll = die importierte/geschätzte Planmenge (bestehendes Feld `menge`).
    var sollMenge: Double { menge }

    // Ist = Summe aller gemessenen Aufmaße.
    var istMengeSumme: Double { aufmassArray.reduce(0) { $0 + $1.istMenge } }

    // Soll minus Ist: positiv = noch nicht voll aufgemessen, negativ = Mehrmenge.
    var abweichung: Double { sollMenge - istMengeSumme }

    var abweichungProzent: Double {
        sollMenge > 0 ? (abweichung / sollMenge) : 0
    }

    var hatAufmass: Bool { !aufmassArray.isEmpty }
}

extension LVPosition: Identifiable {}

// Was für eine Art Deckel ist das? Siehe Kommentar bei `deckelArt`.
// Vorgabe ist bewusst `mengentraeger` — unbekannter/leerer Wert verhält sich wie bisher.
enum DeckelArt: String, CaseIterable {
    case mengentraeger = "mengentraeger"  // Deckel trägt die Menge, Unterpunkte sind Beleg
    case element       = "element"        // Deckel ist die Summe seiner Bausteine (B-Element)

    var anzeige: String {
        switch self {
        case .mengentraeger: return "Mengenträger (Belege)"
        case .element:       return "Element (Bausteine summieren)"
        }
    }
}

// Quelle der MENGEN-Angabe einer LV-Position — getrennt von KalkMaterial.MaterialQuelle,
// weil es hier um die Herkunft der Menge geht (gemessen/geschätzt), nicht um den Preis.
// rawValue == Wire-Format der Box (ExtractLVPosition.quelle), damit der Import
// verlustfrei round-trippt.
enum MengenQuelle: String, CaseIterable {
    case statik     = "statik_tabelle"  // aus der Statik-Tabelle — belastbar/hart
    case bplan      = "b-plan"          // aus dem Bebauungsplan — Planwert
    case schaetzung = "schaetzung"      // geschätzt
    case manuell    = "manuell"         // von Hand eingetragen

    // Belastbar ist heute nur die harte Statik-Tabelle (Box-Etikett "hart"). Alles
    // andere bleibt bis zur BuildIQ-Messung ein Schätzwert und wird in der
    // Voraussetzungs-Ampel (Welle 9) andersfarbig dargestellt. Buch Kap 6:
    // Zustand "gemessen" ≠ Zustand "geschätzt". Unbekannte Quelle → defensiv geschätzt.
    var istGeschaetzt: Bool { self != .statik }
}
