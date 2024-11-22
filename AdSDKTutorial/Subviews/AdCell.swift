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
            AdView(advertisement: advertisement)
                .aspectRatio(aspectRatio, contentMode: .fit)

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
    var state: CellState = .loading

    private var advertisement: Advertisement?

    init(id: Int, _ service: AdService, _ request: AdRequest) async {
        self.id = id

        do {
            let advertisement = try await getAdvertisement(service, request)
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
        _ service: AdService,
        _ request: AdRequest
    ) async throws(AdError) -> Advertisement {
        try await service.makeAdvertisement(
            request: request,
            placementType: .inline, // .inline by default
            targetURLHandler: nil, // Can be skipped
            eventDelegate: nil // Can be skipped
        )
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
