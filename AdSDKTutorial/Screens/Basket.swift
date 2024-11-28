//
//	Basket
//  AdSDKTutorial
//
//  Created by Virtual Minds GmbH on 27.11.2024.
//  Copyright © 2024 Virtual Minds GmbH. All rights reserved.
//

import SwiftUI
import AdSDKCore
import AdSDKSwiftUI

// MARK: - View
struct Basket: View {
    @State var viewModel: BasketViewModel

    var body: some View {
        Form {
            Section {
                LabeledContent("Item id", value: "\(viewModel.id)")
                LabeledContent("Price", value: "€\(viewModel.price)")
                LabeledContent("Quantity", value: "\(viewModel.quantity)")
                Button("+", action: viewModel.onIncreaseQuantity)
                Button("-", action: viewModel.onDecreaseQuantity)
                LabeledContent("Total", value: "€\(viewModel.total)")
            }

            Section {
                Button("Purchase") {
                    Task { await viewModel.onPurchase() }
                }
            }

            if let error = viewModel.error {
                Text(error)
                    .listRowInsets(EdgeInsets())
                    .foregroundStyle(.red)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .center
                    )
                    .background(Color(UIColor.systemGroupedBackground))
            }
        }
        .navigationTitle("Basket")
    }
}

// MARK: - View Model
@Observable
@MainActor
final class BasketViewModel {
    let id: Int
    let price: Int

    var quantity = 1
    var total: Int { price * quantity }
    var error: String?

    private let service: AdService

    init(id: Int, price: Int, _ service: AdService) {
        self.id = id
        self.price = price
        self.service = service
    }
}

extension BasketViewModel {
    func onIncreaseQuantity() { quantity += 1 }
    func onDecreaseQuantity() {
        guard quantity > 1 else { return }

        quantity -= 1
    }

    func onPurchase() async {
        let request = TrackingRequest(
            landingpageId: .zero,
            trackingspotId: .zero,
            orderId: "My purchase id",
            price: Float(price), // Can be skipped
            total: Float(total), // Can be skipped
            quantity: UInt32(quantity), // Can be skipped
            itemNumber: "\(id)", // Can be skipped
            description: nil, // Can be skipped
            timeout: nil // Can be skipped
        )

        do {
            try await service.trackingRequest(request)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
