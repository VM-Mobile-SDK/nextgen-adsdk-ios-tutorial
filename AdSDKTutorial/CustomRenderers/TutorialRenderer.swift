//
//	TutorialRenderer
//  AdSDKTutorial
//
//  Created by Virtual Minds GmbH on 03.12.2024.
//  Copyright © 2024 Virtual Minds GmbH. All rights reserved.
//

import AdSDKCore
import Foundation
import SwiftUI

struct TutorialRenderer: View, AdRenderer {
    @State var controller: TutorialController

    var body: some View {
        if let presentationData = controller.presentationData,
           let banner = UIImage(data: presentationData.banner) {
            Image(uiImage: banner)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .overlay {
                    Rectangle()
                        .stroke(
                            presentationData.isBlackFraming ? .black : .white,
                            lineWidth: presentationData.framingWidth
                        )
                }
                .onTapGesture {
                    Task { await controller.onTap() }
                }
        }
    }
}

@Observable
@MainActor
final class TutorialController: AdController {
    typealias Renderer = TutorialRenderer

    var presentationData: PresentationData?
    weak var delegate: AdControllerDelegate?

    // private let assetRepository: AssetRepository
    private let cache: AssetCache
    private let assetRequestService: AssetRequestService
    private let decoder: JSONDecoder

    init?(_ assetRepository: AssetRepository) {
        // self.assetRepository = assetRepository
        // decoder = .init()
        // decoder.keyDecodingStrategy = .convertFromSnakeCase
        return nil
    }

    init?(_ cache: AssetCache, _ assetRequestService: AssetRequestService) {
        self.cache = cache
        self.assetRequestService = assetRequestService
        decoder = .init()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    // Will be called every time an ad is loaded or reloaded.
    func configure(_ data: Data, _ metadata: AdMetadata) async throws(AdError) {
        let response: TutorialRendererResponse = try decoder.decode(from: data)
        // let bannerResult = try await assetRepository.getAsset(response.bannerURL)
        //
        // switch bannerResult.cacheResult {
        // case .success(let path):
        //     print("TutorialRenderer banner cached: \(path)")
        // case .failure(let error):
        //     print("TutorialRenderer banner caching failed: \(error.localizedDescription)")
        // }
        //
        // let banner = bannerResult.data
        let banner = try await loadBanner(response.bannerURL)
        metadata.rendererMetadata = [
            "custom_message":
            "my custom message to the app"
        ]

        presentationData = .init(
            banner: banner,
            framingWidth: response.framingWidth,
            isBlackFraming: response.isBlackFraming
        )
    }

    private func loadBanner(_ url: URL) async throws(AdError) -> Data {
        let bannerPath = AssetPath(folder: "TutorialRendererResources", url: url)

        // try await cache.remove(bannerPath)

        if let cacheResult = try await cache.read(bannerPath) {
            print("TutorialRenderer banner is used from cache: \(cacheResult.path)")
            return cacheResult.data
        } else {
            print("TutorialRenderer banner is not in the cache yet")
            let data = try await assetRequestService.request(url)

            do {
                let path = try await cache.write(bannerPath, data: data)
                print("TutorialRenderer banner is cached: \(path)")
            } catch {
                print("TutorialRenderer banner caching failed: \(error.localizedDescription)")
            }

            return data
        }
    }

    // Will be called when app want to reload the ad
    func prepareForReload() async throws(AdError) {
        presentationData = nil
    }

    func onTap() async {
        try? await delegate?.performTap(.tap)
        // try? await delegate?.unloadRequest()
        // try? await delegate?.sendMessage(
        //     name: "Message_to_app",
        //     message: "My message to the app"
        // )
    }
}

// MARK: - Models
extension TutorialController {
    struct PresentationData {
        let banner: Data
        let framingWidth: Double
        let isBlackFraming: Bool
    }
}

struct TutorialRendererResponse: Decodable {
    let bannerURL: URL
    let framingWidth: Double
    let isBlackFraming: Bool

    enum Key: String, CodingKey {
        case body, ext, adData
        case bannerURL = "bannerImage"
        case framingWidth
        case isBlackFraming
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let body = try container.nestedContainer(keyedBy: Key.self, forKey: .body)
        let ext = try body.nestedContainer(keyedBy: Key.self, forKey: .ext)
        let adData = try ext.nestedContainer(keyedBy: Key.self, forKey: .adData)

        bannerURL = try adData.decode(URL.self, forKey: .bannerURL)
        framingWidth = try adData.decode(Double.self, forKey: .framingWidth)
        isBlackFraming = try adData.decode(Bool.self, forKey: .isBlackFraming)
    }
}
