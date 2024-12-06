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
    @Environment(\.locale) var locale: Locale

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

                        NavigationLink("Interstitial Screen") {
                            Interstitial(viewModel: .init(adService))
                        }
                    }
                    .alert(
                        "Please grant the permission to track the data.",
                        isPresented: $viewModel.isGDPRAlertShown
                    ) {
                        Button("Allow") { viewModel.onGDPRChange(true) }
                        Button("Deny", role: .cancel) { viewModel.onGDPRChange(false) }
                    }
                    .onChange(of: locale) {
                        Task { await viewModel.onLocaleChange() }
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
    var isGDPRAlertShown = false

    private var service: AdService?
}

extension MainViewModel {
    func configure() async {
        do {
            let service = try await AdService(
                networkID: 1800,
                cacheSize: 20,
                configurationTimeout: 60 // Can be skipped
            )

            service.registerRenderer(TutorialRenderer.self, forName: "tutorialad")
            // do {
            //     try await service.setCacheSize(50)
            // } catch {
            //     print("Error during changing cache size: \(error.localizedDescription)")
            // }

            self.service = service
            state = .ready(service)
            isGDPRAlertShown = true

        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func onGDPRChange(_ permissionGranted: Bool) {
        let consent = "isGranted=\(permissionGranted)"

        guard let service,
              let data = Data(base64Encoded: consent),
              let encodedConsent = String(data: data, encoding: .utf8) else {
            return
        }

        service.setAdRequestGlobalParameter(
            \.gdpr,
             .init(consent: encodedConsent, isRulesEnabled: true)
        )

        // service.removeAdRequestGlobalParameter(\.gdpr)

        service.setTrackingGlobalParameter(
            \.gdpr,
             .init(consent: encodedConsent, isRulesEnabled: true)
        )

        // service.removeTrackingGlobalParameter(\.gdpr)
    }

    func onLocaleChange() async {
        do {
            try await service?.flushCache()
        } catch {
            print("Error during flushing cache: \(error.localizedDescription)")
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
