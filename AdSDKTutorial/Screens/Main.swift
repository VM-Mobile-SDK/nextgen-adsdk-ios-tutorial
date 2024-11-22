//
//  Main
//  AdSDKTutorial
//
//  Created by Virtual Minds GmbH on 20.11.2024.
//  Copyright © 2024 Virtual Minds GmbH. All rights reserved.
//

import SwiftUI
import AdSDKCore
import AdSDKSwiftUI

// MARK: - View
@main
struct Main: App {
    @State var viewModel = MainViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                switch viewModel.state {
                case .loading:
                    Text("Loading")
                        .task { await viewModel.configure() }
                case .ready(let adService):
                    Text("Ready")
                case .error(let description):
                    Text("Error: \(description)")
                }
            }
        }
    }
}

// MARK: - View Model
@Observable
@MainActor
final class MainViewModel {
    var state: AppState = .loading

    private var service: AdService?
}

extension MainViewModel {
    func configure() async {
        do {
            let service = try await AdService(
                networkID: 1800,
                cacheSize: 100, // Can be skipped
                configurationTimeout: 60 // Can be skipped
            )

            self.service = service
            state = .ready(service)

        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

// MARK: - Models
extension MainViewModel {
    enum AppState {
        case loading
        case ready(AdService)
        case error(String)
    }
}
