//
//  AdCell
//  AdSDKTutorial
//
//  Created by Virtual Minds GmbH on 21.11.2024.
//  Copyright © 2024 Virtual Minds GmbH. All rights reserved.
//

import SwiftUI
import AdSDKCore
import AdSDKSwiftUI

// MARK: - View
struct AdCell: View {
    @State var viewModel: AdCellViewModel

    var body: some View {
        switch viewModel.state {
        case .loading:
            Text("Loading")
        case let .loaded(advertisement, aspectRatio):
            VStack {
                AdView(advertisement: advertisement)
                    .aspectRatio(aspectRatio, contentMode: .fit)

                HStack {
                    Text("Price: €\(viewModel.price)")
                    Spacer()
                    NavigationLink("Add to basket") {
                        Basket(viewModel: .init(
                            id: viewModel.id,
                            price: viewModel.price,
                            viewModel.service
                        ))
                        .task { await viewModel.onBasket() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }

        case .error(let description):
            Text("Error: \(description)")
        }
    }
}

// MARK: - View Model
@Observable
@MainActor
final class AdCellViewModel: Identifiable {
    let id: Int
    let price: Int = .random(in: 10...200)
    let service: AdService
    var state: CellState = .loading

    private var advertisement: Advertisement?

    init(
        id: Int,
        _ service: AdService,
        _ request: AdRequest,
        _ targetURLHandler: TargetTapURLHandler
    ) async {
        self.id = id
        self.service = service

        do {
            let advertisement = try await getAdvertisement(
                request,
                targetURLHandler
            )

            self.advertisement = advertisement

            let ratio = advertisement.metadata?.aspectRatio ?? 2

            state = .loaded(advertisement, aspectRatio: ratio)

        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

private extension AdCellViewModel {
    func getAdvertisement(
        _ request: AdRequest,
        _ targetURLHandler: TargetTapURLHandler
    ) async throws(AdError) -> Advertisement {
        try await service.makeAdvertisement(
            request: request,
            placementType: .inline, // .inline by default
            targetURLHandler: targetURLHandler,
            eventDelegate: self
        )
    }

    func onBasket() async {
        let request = TagRequest(
            [.init(key: "MyTutorialStore", subkey: "Movies", value: "\(id)")],
            timeout: nil // Can be skipped
        )

        do {
            try await service.tagUser(request: request)
        } catch {
            print("Error during user tagging: \(error.localizedDescription)")
        }
    }
}

extension AdCellViewModel: AdEventDelegate {
    func unloadRequest() {
        state = .error("Unloaded")
        advertisement = nil
    }

    func trackingEventProcessed(
        _ event: TrackingEvent,
        processedURLs: [URL],
        metadata: AdMetadata
    ) {
        switch event {
        case .impression:
            print("My ad is ready")
        case .showingAsset(let id):
            print("Asset with id \(id) currently presented on a screen.")
        case .viewable(let percentage):
            print("\(percentage)% of my ads are now visible on the screen.")
        @unknown default: print("Unexpected event")
        }

        print("SDK notified server about that via URLs: \(processedURLs)")
    }

    func trackingEventProcessingFailed(
        _ event: TrackingEvent,
        processedURLs: [URL],
        failedURLs: [URL : AdError]
    ) async -> AdEventFailureAction {
        switch event {
        case .impression:
            print("My ad is ready")
        case .showingAsset(let id):
            print("Asset with id \(id) currently presented on a screen.")
        case .viewable(let percentage):
            print("\(percentage)% of my ads are now visible on the screen.")
        @unknown default: print("Unexpected event")
        }

        print("SDK notified server about that via URLs: \(processedURLs)")
        print("But failed during requesting those: \(failedURLs)")

        return .ignore
    }

    func tapEventProcessed(
        _ event: TapEvent,
        processedURL: URL,
        metadata: AdMetadata
    ) {
        switch event {
        case .tap, .tapURL:
            print("My ad was tapped")
            print("\(processedURL) opened for the user")
        case .tapAsset(let id):
            print("My banner with \(id) was tapped")
            print("\(processedURL) opened for the user")
        case .silentTap(let url):
            print("My renderer want to process click counter \(url) redirect")
            print("As a result of redirects we get \(url)")
            print("This URL is NOT opened for the user")

        @unknown default: print("Unexpected event")
        }
    }

    func tapEventProcessingFailed(
        _ event: TapEvent,
        _ error: AdError
    ) async -> AdEventFailureAction {
        switch event {
        case .tap, .tapURL:
            print("My ad was tapped")
        case .tapAsset(let id):
            print("My banner with \(id) was tapped")
        case .silentTap(let url):
            print("My renderer want to process click counter \(url) redirect")
        @unknown default: print("Unexpected event")
        }

        print("But failed during processing tap with error: \(error.localizedDescription)")

        return .ignore
    }

    func rendererMessageReceived(name: String, message: String?) {
        print("Renderer sent event \(name), message: \(String(describing: message)).")
        print("We can create custom logic in the application based on it.")
    }

    func customTrackingEventProcessed(name: String, url: URL, metadata: AdMetadata) {
        print("Renderer perform custom tracking event \(name)")
        print("\(url) was requested")
    }

    func customTrackingEventProcessingFailed(
        name: String,
        url: URL,
        _ error: AdError
    ) async -> AdEventFailureAction {
        print("Renderer perform custom tracking event \(name)")
        print("But request to \(url) failed with error \(error.localizedDescription)")

        return .ignore
    }
}

// MARK: - Models
extension AdCellViewModel {
    enum CellState {
        case loading
        case loaded(Advertisement, aspectRatio: Double)
        case error(String)
    }
}
