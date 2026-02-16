import Foundation
import CoreData

enum KnowledgeImporter {

    static func importIfNeeded(into context: NSManagedObjectContext) {
        let productCount = (try? context.count(for: CDProduct.fetchRequest())) ?? 0
        let lexCount = (try? context.count(for: CDLexikonEntry.fetchRequest())) ?? 0
        print("🧠 KnowledgeImporter: importIfNeeded() wurde aufgerufen")

        if productCount > 0 || lexCount > 0 {
            print("ℹ️ Knowledge Import: Daten vorhanden (Products: \(productCount), Lexikon: \(lexCount)). Skip.")
            return
        }

        importProducts(into: context)
        importLexikon(into: context)

        do {
            try context.save()
            print("🚀 Knowledge Import abgeschlossen.")
        } catch {
            print("🚨 Save Fehler nach Import: \(error)")
        }
    }

    // MARK: - Produkte

    private static func importProducts(into context: NSManagedObjectContext) {
        guard let url = Bundle.main.url(forResource: "Produkte", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("🚨 Produkte.json nicht gefunden.")
            return
        }

        do {
            let decoded = try JSONDecoder().decode([JSONProduct].self, from: data)

            // ✅ Dedupe nach ID: letzter Eintrag gewinnt
            var byID: [String: JSONProduct] = [:]
            var duplicateCount = 0

            for p in decoded {
                if byID[p.id] != nil {
                    duplicateCount += 1
                    print("⚠️ Duplicate Product ID gefunden: \(p.id) -> letzter Eintrag gewinnt")
                }
                byID[p.id] = p
            }

            // ✅ deterministische Reihenfolge
            let uniqueProducts = byID
                .values
                .sorted { $0.id < $1.id }

            if duplicateCount > 0 {
                print("ℹ️ Dedup abgeschlossen: \(duplicateCount) Duplikate entfernt. Unique: \(uniqueProducts.count)")
            } else {
                print("ℹ️ Dedup abgeschlossen: keine Duplikate. Unique: \(uniqueProducts.count)")
            }

            // ✅ BatchInsert MUSS uniqueProducts verwenden (nicht decoded)
            var index = 0
            let productInsert = NSBatchInsertRequest(
                entityName: "CDProduct",
                managedObjectHandler: { managedObject in
                    guard index < uniqueProducts.count else { return true }
                    let jsonP = uniqueProducts[index]
                    index += 1

                    let obj = managedObject as! CDProduct
                    obj.id = jsonP.id
                    obj.name = jsonP.name
                    obj.category = jsonP.kategorie
                    obj.dataSource = jsonP.typ
                    obj.beschreibung = jsonP.beschreibung
                    obj.allergene = jsonP.mergedAllergene
                    obj.zusatzstoffe = jsonP.mergedZusatzstoffe
                    obj.kcal = jsonP.mergedKcal
                    obj.fett = jsonP.mergedFett
                    obj.zucker = jsonP.mergedZucker
                    obj.stockQuantity = 0
                    obj.stockUnit = "Stk."

                    if let rezept = jsonP.rezept {
                        obj.portionen = rezept.portionen
                        obj.algorithmusText = rezept.algorithmus.joined(separator: "\n")
                    }

                    return false
                }
            )
            productInsert.resultType = .statusOnly
            _ = try context.execute(productInsert)

            // ✅ Ingredients separat (Relationship)
            // Nur unique IDs verwenden
            let ids = uniqueProducts.map { $0.id }

            let fetch: NSFetchRequest<CDProduct> = CDProduct.fetchRequest()
            fetch.predicate = NSPredicate(format: "id IN %@", ids)
            fetch.fetchBatchSize = 500

            let fetchedProducts = try context.fetch(fetch)

            // ✅ Map: id -> CDProduct
            var productByID: [String: CDProduct] = [:]
            productByID.reserveCapacity(fetchedProducts.count)

            for p in fetchedProducts {
                if let id = p.id {
                    productByID[id] = p
                }
            }

            // ✅ Ingredients ebenfalls über uniqueProducts (nicht decoded)
            for p in uniqueProducts {
                guard let rezept = p.rezept else { continue }
                guard let cdProduct = productByID[p.id] else { continue }

                for ing in rezept.komponenten {
                    let i = CDIngredient(context: context)
                    i.name = ing.name
                    i.menge = ing.menge
                    i.einheit = ing.einheit
                    i.product = cdProduct
                }
            }

            print("✅ Produkte geladen (decoded: \(decoded.count), unique: \(uniqueProducts.count))")
        } catch {
            print("🚨 Parse Fehler Produkte.json: \(error)")
        }
    }

    // MARK: - Lexikon

    // MARK: - Lexikon

    private static func importLexikon(into context: NSManagedObjectContext) {
        guard let url = Bundle.main.url(forResource: "Lexikon", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("🚨 Lexikon.json nicht gefunden.")
            return
        }

        do {
            let raw = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []

            // ✅ Dedupe: Code ist primär, sonst Name+Kategorie
            var byKey: [String: [String: Any]] = [:]
            var duplicateCount = 0

            for e in raw {
                let code = (e["code"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let name = (e["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let kat  = (e["kategorie"] as? String ?? "Fachbuch").trimmingCharacters(in: .whitespacesAndNewlines)

                // Leere Einträge ignorieren
                if name.isEmpty && code.isEmpty { continue }

                let key = !code.isEmpty ? "CODE:\(code)" : "NAME:\(name)|KAT:\(kat)"

                if byKey[key] != nil {
                    duplicateCount += 1
                    if !code.isEmpty {
                        print("⚠️ Duplicate Lexikon CODE gefunden: \(code) -> letzter Eintrag gewinnt")
                    } else {
                        print("⚠️ Duplicate Lexikon NAME/KAT gefunden: \(name) / \(kat) -> letzter Eintrag gewinnt")
                    }
                }
                byKey[key] = e
            }

            let uniqueRaw = Array(byKey.values)

            if duplicateCount > 0 {
                print("ℹ️ Lexikon-Dedup: \(duplicateCount) Duplikate entfernt. Unique: \(uniqueRaw.count)")
            } else {
                print("ℹ️ Lexikon-Dedup: keine Duplikate. Unique: \(uniqueRaw.count)")
            }

            // ✅ BatchInsert
            var index = 0
            let insert = NSBatchInsertRequest(
                entityName: "CDLexikonEntry",
                managedObjectHandler: { managedObject in
                    guard index < uniqueRaw.count else { return true }
                    let e = uniqueRaw[index]
                    index += 1

                    let code = (e["code"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let name = (e["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

                    // Ohne Name macht es wenig Sinn (du kannst das lockern, wenn du willst)
                    if name.isEmpty { return false }

                    let obj = managedObject as! CDLexikonEntry
                    obj.code = code
                    obj.name = name
                    obj.kategorie = (e["kategorie"] as? String) ?? "Fachbuch"
                    obj.beschreibung = (e["beschreibung"] as? String) ?? ""
                    obj.details = (e["details"] as? String) ?? ""

                    return false
                }
            )
            insert.resultType = .statusOnly

            _ = try context.execute(insert)
            print("📚 Lexikon geladen (raw: \(raw.count), unique: \(uniqueRaw.count))")
        } catch {
            print("🚨 Parse Fehler Lexikon.json: \(error)")
        }
    }
}
