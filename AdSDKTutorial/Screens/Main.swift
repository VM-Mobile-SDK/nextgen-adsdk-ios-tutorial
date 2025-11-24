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
    @State private var isDataCollectionAlertShown = true
    @Environment(\.locale) var locale: Locale

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                switch viewModel.state {
                case .loading:
                    Text("Loading")
                        .alert(
                            "Please grant the permission to collect the data",
                            isPresented: $isDataCollectionAlertShown
                        ) {
                            Button("Allow") {
                                isDataCollectionAlertShown = false

                                Task {
                                    await viewModel.configure(
                                        isDataCollectionAllowed: true
                                    )
                                }
                            }

                            Button("Deny", role: .cancel) {
                                isDataCollectionAlertShown = false

                                Task {
                                    await viewModel.configure(
                                        isDataCollectionAllowed: false
                                    )
                                }
                            }
                        }
                case .ready(let adService):
                    VStack {
                        NavigationLink("Inline Ads List") {
                            InlineList(viewModel: .init(adService))
                        }

                        NavigationLink("Interstitial Screen") {
                            Interstitial(viewModel: .init(adService))
                        }
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

    private var service: AdService?
}

extension MainViewModel {
    func configure(isDataCollectionAllowed: Bool) async {
        do {
            let service = try await AdService(
                networkID: 1800,
                cacheSize: 20, // Can be skipped
                configurationTimeout: 60, // Can be skipped
                globalParameters: GlobalParameters( // Can be skipped
                    accessMode: isDataCollectionAllowed.toAccessMode()
                )
            )

            service.setTrackingGlobalParameter(\.externalUID, .init(uid: "UID"))
            service.removeTrackingGlobalParameter(\.externalUID)

            service.setAdRequestGlobalParameter(\.externalUID, .init(uid: "UID"))
            service.removeAdRequestGlobalParameter(\.externalUID)

            // Can have unique global parameters for ad requests
            service.setAdRequestGlobalParameter(
                \.cookiesAccess,
                 isDataCollectionAllowed.toCookieAccess()
            )

            service.registerRenderer(TutorialRenderer.self, forName: "tutorialad")
            // do {
            //     try await service.setCacheSize(50)
            // } catch {
            //     print("Error during changing cache size: \(error.localizedDescription)")
            // }

            self.service = service
            state = .ready(service)

        } catch {
            state = .error(error.localizedDescription)
        }
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

// MARK: - Private Extensions
private extension Bool {
    func toAccessMode() -> GlobalParameters.AccessMode {
        self ? .optIn : .optOut
    }

    func toCookieAccess() -> AdRequestGlobalParameters.CookiesAccess {
        self ? .get : .noCookies
    }
}
