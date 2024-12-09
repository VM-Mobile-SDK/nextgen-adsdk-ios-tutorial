//
//	Browser
//  AdSDKTutorial
//
//  Created by Virtual Minds GmbH on 02.12.2024.
//  Copyright © 2024 Virtual Minds GmbH. All rights reserved.
//

import SwiftUI
import SafariServices

struct Browser: UIViewControllerRepresentable {
    let targetURL: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: targetURL)
    }

    func updateUIViewController(
        _ uiViewController: SFSafariViewController,
        context: Context
    ) {}
}
