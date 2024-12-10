//
//	JSONDecoder+Extensions
//  AdSDKTutorial
//
//  Created by Virtual Minds GmbH on 03.12.2024.
//  Copyright © 2024 Virtual Minds GmbH. All rights reserved.
//

import Foundation
import AdSDKCore

extension JSONDecoder {
    /// Convenient method to decode `Decodable` objects with possible `AdError` throwing.
    func decode<T: Decodable>(from data: Data) throws(AdError) -> T {
        do {
            return try decode(T.self, from: data)
        // Handle decoding error
        } catch let error as DecodingError {
            throw .decoding(description: error.decodingMessage)
        // Handle AdError thrown from decoding logic
        } catch let error as AdError {
            throw error
        // Handle other errors during decoding
        } catch {
            throw .decoding(description: error.localizedDescription)
        }
    }
}

// MARK: - DecodingError + Extensions
extension DecodingError {
    var decodingMessage: String {
        switch self {
        case let .typeMismatch(type, context):
            """
            Type '\(type)' mismatch: \(context.debugDescription)
            CodingPath: \(context.codingPath)"
            """
        case let .valueNotFound(value, context):
            """
            Value '\(value)' not found: \(context.debugDescription)
            CodingPath: \(context.codingPath)
            """
        case let .keyNotFound(key, context):
            """
            Key '\(key)' not found: \(context.debugDescription)
            CodingPath: \(context.codingPath)
            """
        case let .dataCorrupted(context):
            """
            Data corrupted: \(context.debugDescription)
            CodingPath: \(context.codingPath)
            """
        @unknown default: "Unknown decoding error: \(localizedDescription)."
        }
    }
}
