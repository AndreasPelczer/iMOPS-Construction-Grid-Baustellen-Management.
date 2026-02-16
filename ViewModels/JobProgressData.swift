//
//  test25B
//
//  Created by Andreas Pelczer on 15.12.25.
//
// ViewModels/JobProgressData.swift

import Foundation

/**
 * 📊 Berechnet und hält die Fortschrittsdaten für ein einzelnes Event.
 * Kommentar: Diese Struktur übernimmt die Logik zum Zählen der Aufträge nach Status.
 */
struct EventJobProgressData {
    let totalJobs: Int
    let completedCount: Int
    let inProgressCount: Int
    let pendingCount: Int
    let onHoldCount: Int
    
    init(event: Event) {
        guard let jobs = event.jobs as? Set<Auftrag> else {
            // Kommentar: Keine Jobs vorhanden
            self.totalJobs = 0
            self.completedCount = 0
            self.inProgressCount = 0
            self.pendingCount = 0
            self.onHoldCount = 0
            return
        }
        
        self.totalJobs = jobs.count
        
        // Kommentar: Zählen der Aufträge nach Status
        self.completedCount = jobs.filter { $0.status == .completed }.count
        self.inProgressCount = jobs.filter { $0.status == .inProgress }.count
        self.pendingCount = jobs.filter { $0.status == .pending }.count
        self.onHoldCount = jobs.filter { $0.status == .onHold }.count
    }
}
