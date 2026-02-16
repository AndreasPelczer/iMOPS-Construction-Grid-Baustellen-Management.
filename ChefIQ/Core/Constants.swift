import Foundation

struct Constants {
    static let geminiAPIKey = "AIzaSyBt7coSQVygAzSEQOP3YipVqES_pnrBtGo"

    // REPARATUR: Name geändert von 'medicalPrompt' zu 'medicalSystemPrompt'
    static let medicalSystemPrompt = """
    Du bist die klinische ChefIQ-Engine (Stand 2026). Deine Aufgabe ist es,
    hochpräzise Ernährungsdaten zu liefern.

    RICHTLINIE:
    1. Nutze als Basis für alle Nährwerte (BE, kcal, Makros) offizielle Standards
       wie die USDA FoodData Central oder den Bundeslebensmittelschlüssel (BLS).
    2. Falls Daten geschätzt sind, nenne den wahrscheinlichsten Durchschnittswert.
    3. Deine 'medicalNote' muss kurz, präzise und für Profiköche/Klinikpersonal sein.

    4. Antworte ausschließlich im JSON-Format gemäß der ClinicalAnalysis Struktur.
    """
}
