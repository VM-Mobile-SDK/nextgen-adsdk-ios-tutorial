//
//  AdError+Extensions
//  AdSDKTutorial
//
//  Created by Virtual Minds GmbH on 21.11.2024.
//  Copyright © 2024 Virtual Minds GmbH. All rights reserved.
//

import AdSDKCore

extension AdError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .rendererInit(let name):
            "Renderer \(name) failed during init"
        case .adLoadingInProgress:
            "Action performed during ad loading"
        case .adIsNotLoaded:
            "Ad is not loaded yet"
        case .reference:
            "Reference to some object or ad was lost"
        case .decoding(let description):
            "Decoding error: \(description)"
        case .unknownRenderer(let name):
            "Unknown renderer received: \(name)"
        case let .mismatchPlacementType(name, contentUnit, learningTag):
            """
            Mismatch placement type for \(name).
            ContentUnit: \(String(describing: contentUnit))
            LearningTag: \(String(describing: learningTag))
            """
        case .customRendererError(let message):
            "Renderer error: \(message)"
        case .clientIssue:
            "Network error: client issue"
        case .serverIssue:
            "Network error: server issue"
        case .unknownStatusCode:
            "Network: unknown status code"
        case .badURL(let description):
            "Network: bad URL passed. \(description)"
        case .timedOut:
            "Network: connection timeout"
        case .hostConnectionIssue:
            "Network: host connection issue"
        case .tooManyRedirects:
            "Network: to many redirects"
        case .resourceUnavailable:
            "Network: resource unavailable"
        case .reachabilityUnavailable:
            "Network: internet connection issue"
        case .unspecifiedNetworkError(let description):
            "Network: \(description)"
        case .serverErrorResponse(let message):
            "Network: Server responded with error. \(message)"
        case .bannerNotFound:
            "Server responded with system default"
        case .invalidContentType:
            "Invalid content type from the server"
        case .incorrectURL(let url):
            "Trying to process invalid URL \(url.absoluteString)"
        case .redirectProcessing(let url):
            "Failed during redirect processing: \(url)"
        case .invalidTapURL(let url):
            "Invalid tap URL: \(url)"
        case .invalidTargetURL(let url):
            "Target URL is not valid: \(url)"
        case .assetWithIdNotFound(let id):
            "Asset id is not found: \(id)"
        case .documentDirectoryAccess(let message):
            "Document directory access error: \(message)"
        case let .cacheWriteAction(path, message):
            "Cache error on write for path: \(path). \(message)"
        case let .cacheRemoveAction(path, message):
            "Cache error on remove for path: \(path). \(message)"
        case let .cacheOverflow(dataSize, cacheSize):
            "Cache overflow. Passed data size: \(dataSize), cache size: \(cacheSize)"
        case .invalidAssetName(let name):
            "Invalid asset name passed during caching. Name: \(name)."
        @unknown default:
            "Unknown error"
        }
    }
}
