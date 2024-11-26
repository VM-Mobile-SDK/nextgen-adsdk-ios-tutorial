//
//  InlineList
//  AdSDKTutorial
//
//  Created by Virtual Minds GmbH on 22.11.2024.
//  Copyright © 2024 Virtual Minds GmbH. All rights reserved.
//

import AdSDKCore
import AdSDKSwiftUI
import SwiftUI

// MARK: - View
struct InlineList: View {
    @State var viewModel: InlineListViewModel

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(viewModel.dataSource) { viewModel in
                    AdCell(viewModel: viewModel)
                }
            }
        }
        .adsContainer()
        .navigationTitle("Inline Ads List")
        .task {
            await viewModel.fetchAds()
        }
    }
}

// MARK: - View Model
@Observable
@MainActor
final class InlineListViewModel {
    var dataSource = [AdCellViewModel]()

    private let service: AdService

    init(_ service: AdService) {
        self.service = service
    }
}

extension InlineListViewModel {
    func fetchAds() async {
        let requests = Array(repeating: 4810915, count: 5).map {
            AdRequest(
                contentUnit: $0,
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
        }

        dataSource = await getDataSource(service, requests)
    }

    private nonisolated func getDataSource(
        _ service: AdService,
        _ requests: [AdRequest]
    ) async -> [AdCellViewModel] {
        await withTaskGroup(
            of: AdCellViewModel.self,
            returning: [AdCellViewModel].self
        ) { group in
            for i in Int.zero..<requests.count {
                let request = requests[i]
                group.addTask {
                    await .init(id: i, service, request)
                }
            }

            let result = await group.reduce(
                into: [AdCellViewModel]()
            ) { result, cell in
                result.append(cell)
            }

            return result.sorted { $0.id < $1.id }
        }
    }
}
