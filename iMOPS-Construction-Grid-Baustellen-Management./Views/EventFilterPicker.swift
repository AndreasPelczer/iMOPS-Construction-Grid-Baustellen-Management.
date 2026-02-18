//
//  EventFilterPicker.swift
//  iMOPS-Construction-Grid-Baustellen-Management.
//

import SwiftUI

struct EventFilterPicker: View {
    @Binding var selectedFilter: EventFilter

    var body: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(EventFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }
}
