//
//  ios_TrashPicUpApp.swift
//  ios_TrashPicUp
//
//  Created by Madison Murphy on 1/25/26.
//

import SwiftUI

#if os(iOS)
@main
#endif
struct ios_TrashPicUpApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .frame(minWidth: 900, minHeight: 600)
                #endif
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        #endif
    }
}
