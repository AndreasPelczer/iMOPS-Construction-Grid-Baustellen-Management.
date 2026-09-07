import Foundation
import CoreData

extension Bautagesbericht {

    @nonobjc class func fetchRequest() -> NSFetchRequest<Bautagesbericht> {
        NSFetchRequest<Bautagesbericht>(entityName: "Bautagesbericht")
    }

    @NSManaged var id: UUID?
    @NSManaged var datum: Date?
    @NSManaged var witterung: String?
    @NSManaged var temperatur: String?
    @NSManaged var personalAnzahl: Int16
    @NSManaged var geraete: String?
    @NSManaged var ausgefuehrteArbeiten: String?
    @NSManaged var behinderungen: String?
    @NSManaged var notizen: String?
    @NSManaged var erstelltAm: Date?
    @NSManaged var autor: String?

    /// Gesetzt beim Freigeben. Ab dann ist der Bericht ein Nachweis und wird
    /// nicht mehr geändert — eine Korrektur ist ein NEUER Bericht mit Bezug.
    @NSManaged var gesperrtAm: Date?
    @NSManaged var freigegebenVon: String?
    /// Zeigt auf den Bericht, den dieser hier korrigiert. Das Original bleibt.
    @NSManaged var korrigiertVonID: UUID?

    // Zählstände zum Zeitpunkt des Speicherns — eingefroren, nicht live.
    // Ein Bericht dokumentiert SEINEN Tag. Würden diese Zahlen beim Anzeigen
    // aus dem Event gezogen, zeigte ein zwei Monate alter Bericht die Mängel
    // von heute — die App schriebe still die Vergangenheit um.
    @NSManaged var snapAuftraegeGesamt: Int16
    @NSManaged var snapAuftraegeOffen: Int16
    @NSManaged var snapLVPositionen: Int16
    @NSManaged var snapMaengel: Int16

    @NSManaged var event: Event?

    /// Ein freigegebener Bericht ist unveränderlich.
    var istGesperrt: Bool { gesperrtAm != nil }

    /// Korrektur-Einträge zeigen auf ihr Original.
    var istKorrektur: Bool { korrigiertVonID != nil }
}
