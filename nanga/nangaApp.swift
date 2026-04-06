//
//  nangaApp.swift
//  nanga
//
//  Created by Nawal 🫧💗🛼 on 06/04/2026.
//

import SwiftUI

@main
struct nangaApp: App {
    @State private var appModel = NangaAppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }
    }
}
