//
//  AuftragProgressData.swift
//  test25B
//
//  Created by Andreas Pelczer on 15.01.26.
//


import Foundation

struct AuftragProgressData {
    let status: AuftragStatus
    let checklistDone: Int
    let checklistTotal: Int

    /// Wenn Checkliste vorhanden: Checklistenfortschritt, sonst Fallback aus Status.
    var ratio: Double {
        if checklistTotal > 0 {
            return Double(checklistDone) / Double(checklistTotal)
        }
        switch status {
        case .pending: return 0.15
        case .inProgress: return 0.55
        case .onHold: return 0.35
        case .completed: return 1.0
        }
    }
}

// Kompatibilität (falls im Projekt noch "JobProgressData" vorkommt)
typealias JobProgressData = AuftragProgressData
