//
//  JSONProduct.swift
//  test25B
//
//  Created by Andreas Pelczer on 12.01.26.
//


import Foundation

// MARK: - Root Product DTO
struct JSONProduct: Decodable {
    let id: String
    let name: String
    let kategorie: String
    let typ: String
    let beschreibung: String?

    // ✅ Neu: optional auch top-level möglich
    let allergene: String?
    let zusatzstoffe: String?

    // (optional, falls solche Felder irgendwann flach kommen)
    let kcal_100g: String?
    let fett: String?
    let zucker: String?

    let metadata: JSONProductMetadata?
    let rezept: JSONRecipe?

    // ✅ Hilfszugriff: "merged" Werte
    var mergedAllergene: String? {
        let m = metadata?.allergene?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let m, !m.isEmpty { return m }

        let t = allergene?.trimmingCharacters(in: .whitespacesAndNewlines)
        return t?.isEmpty == false ? t : nil
    }

    var mergedZusatzstoffe: String? {
        let m = metadata?.zusatzstoffe?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let m, !m.isEmpty { return m }

        let t = zusatzstoffe?.trimmingCharacters(in: .whitespacesAndNewlines)
        return t?.isEmpty == false ? t : nil
    }

    var mergedKcal: String? {
        let m = metadata?.kcal_100g?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let m, !m.isEmpty { return m }

        let t = kcal_100g?.trimmingCharacters(in: .whitespacesAndNewlines)
        return t?.isEmpty == false ? t : nil
    }

    var mergedFett: String? {
        let m = metadata?.fett?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let m, !m.isEmpty { return m }

        let t = fett?.trimmingCharacters(in: .whitespacesAndNewlines)
        return t?.isEmpty == false ? t : nil
    }

    var mergedZucker: String? {
        let m = metadata?.zucker?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let m, !m.isEmpty { return m }

        let t = zucker?.trimmingCharacters(in: .whitespacesAndNewlines)
        return t?.isEmpty == false ? t : nil
    }
}

// MARK: - Metadata
struct JSONProductMetadata: Decodable {
    let allergene: String?
    let zusatzstoffe: String?
    let kcal_100g: String?
    let fett: String?
    let zucker: String?
}

// MARK: - Recipe
struct JSONRecipe: Decodable {
    let portionen: String
    let algorithmus: [String]
    let komponenten: [JSONIngredient]
}

// MARK: - Ingredient
struct JSONIngredient: Decodable {
    let name: String
    let menge: String
    let einheit: String
}
