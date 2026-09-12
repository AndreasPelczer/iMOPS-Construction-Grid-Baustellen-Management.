import Foundation
import CoreData

// Leistungsbaustein — ein wiederverwendbarer LV-Baustein mit Aufwandswert.
//
// Bogen 1 des Leistungskatalog-Fahrplans (Grap8): „einmal fragen → für immer im Katalog".
// Wenn am Grap8-Knoten ein Prof-Aufwandswert übernommen wird (Bogen 0), wird die Leistung
// hier als Baustein abgelegt (Leistung + Einheit + Maurer/Helfer-Stunden). Beim nächsten
// gleichnamigen Knoten kann man den Baustein PICKEN, statt den Prof erneut zu fragen — die
// Kühlhaus-Regel als Feature. Persistiert & wachsend, anders als der statische
// `LVBausteinKatalog` (der trägt Preise, nicht Aufwandswerte).
@objc(Leistungsbaustein)
class Leistungsbaustein: NSManagedObject {}
