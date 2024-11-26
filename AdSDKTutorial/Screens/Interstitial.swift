//
//	Interstitial
//  AdSDKTutorial
//
//  Created by Virtual Minds GmbH on 25.11.2024.
//  Copyright © 2024 Virtual Minds GmbH. All rights reserved.
//

import SwiftUI
import AdSDKCore
import AdSDKSwiftUI

// MARK: - View
struct Interstitial: View {
    @State var viewModel: InterstitialViewModel

    var body: some View {
        switch viewModel.state {
        case .loading:
            Text("Loading")
                .task { await viewModel.loadAdvertisement() }

        case .ready:
            VStack {
                Button("Present", action: viewModel.presentTapped)
            }
            .interstitial($viewModel.interstitialState)

        case .error(let description):
            Text("Error: \(description)")
        }
    }
}

// MARK: - View Model
@Observable
@MainActor
final class InterstitialViewModel {
    var state: ViewState = .loading
    var interstitialState: AdInterstitialState = .hidden

    private let service: AdService
    private var advertisement: Advertisement?

    init(_ service: AdService) {
        self.service = service
    }
}

extension InterstitialViewModel {
    func presentTapped() {
        guard let advertisement else { return }

        interstitialState = .presentedIfLoaded(advertisement)
    }

    func loadAdvertisement() async {
        let request = AdRequest(
            contentUnit: 5192923,
            profile: nil, // Can be skipped
            keywords: nil, // Can be skipped
            window: nil, // Can be skipped
            timeoutAfterSeconds: nil, // Can be skipped
            gdprPd: nil, // Can be skipped
            campaignId: nil, // Can be skipped
            bannerId: nil, // Can be skipped
            isSHBEnabled: nil, // Can be skipped
            dsa: nil // Can be skipped
        )

        do {
            advertisement = try await service.makeAdvertisement(
                request: request,
                placementType: .interstitial, // Should be interstitial
                targetURLHandler: nil, // Can be skipped
                eventDelegate: nil // Can be skipped
            )

            state = .ready

        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

extension InterstitialViewModel: AdEventDelegate {
    func unloadRequest() { interstitialState = .hidden }
}

// MARK: - Models
extension InterstitialViewModel {
    enum ViewState {
        case loading, ready
        case error(String)
    }
}
