//
//	TargetTapURLHandler
//  AdSDKTutorial
//
//  Created by Virtual Minds GmbH on 02.12.2024.
//  Copyright © 2024 Virtual Minds GmbH. All rights reserved.
//

import UIKit
import AdSDKCore

struct TargetTapURLHandler: TargetURLHandler {
    var onReceive: @MainActor (TargetURL) -> Void

    @MainActor
    func isValidURL(_ url: URL) async -> Bool { // Can be skipped
        UIApplication.shared.canOpenURL(url)
    }

    func handleURL(_ url: URL) async {
        await onReceive(.init(url: url))
    }
}

struct TargetURL: Identifiable {
    let id: String
    let url: URL

    init(url: URL) {
        self.id = url.absoluteString
        self.url = url
    }
}
