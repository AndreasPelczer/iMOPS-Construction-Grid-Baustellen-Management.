//
//  JobRowViewModel.swift
//  test25B
//
//  Created by Andreas Pelczer on 15.01.26.
//

import Foundation
import CoreData

func updateStatus(_ newStatus: JobStatus, context: NSManagedObjectContext) {
  //  job.status = newStatus

    // Optional: Startzeit setzen beim Start
    if newStatus == .inProgress {
   //     job.lastStartTime = Date()
    }

    do {
        try context.save()
    } catch {
        print("❌ updateStatus save error:", error)
    }
}
