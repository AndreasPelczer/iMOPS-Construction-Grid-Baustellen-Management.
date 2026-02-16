// EventListView.swift

import SwiftUI
import CoreData // CoreData ist nötig für Event Typ

struct EventListView: View {
    // 1. Nimmt die Liste von Events direkt entgegen (muss nicht @Published sein)
    @Binding var events: [Event]
    
    // 2. Nimmt die Lösch-Funktion entgegen
    let onDelete: (IndexSet) -> Void

    // 3. DateFormatter kopieren, um die Abhängigkeit zu reduzieren
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        ForEach(events) { event in
            NavigationLink(destination: EventDetailView(event: event)) {
                // KORREKTUR: Aufruf der dedizierten Zeilen-View
                EventRowView(event: event) // <--- RUFT DIE NEUE VIEW AUF
            }
        }
        .onDelete(perform: onDelete)
    }
}
