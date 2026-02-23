//
//  Main
//  AdSDKTutorial
//
//  Created by Virtual Minds GmbH on 20.11.2024.
//  Copyright © 2024 Virtual Minds GmbH. All rights reserved.
//

import SwiftUI
import AdSDK

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
                    VStack {
                        NavigationLink("Inline Ads List") {
                            InlineList(viewModel: .init(adService))
                        }
                    }

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

    private var provider: AdServiceProviderInterface = AdServiceProvider()
}

extension MainViewModel {
    func configure() async {
        do {
            try await provider.configure(
                networkID: 1800,
                cacheSize: 100, // Can be skipped
                configurationTimeout: 60 // Can be skipped
            )

            let service = try await provider.get()
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
