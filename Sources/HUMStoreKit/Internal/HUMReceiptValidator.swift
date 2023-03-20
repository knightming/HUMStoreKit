//
//  HUMReceiptValidator.swift
//  
//
//  Created by Henry on 2022/8/2.
//

import Foundation

final class HUMReceiptValidator {
    private init() { }
    
    class func validate(
        receiptData: Data,
        sharedSecret: String? = nil,
        excludeOldTransactions: Bool? = nil,
        completion: @escaping (HUMStoreReceiptVerifyResult) -> Void
    ) {
        let receiptBase64 = receiptData.base64EncodedString(options: [])
        validate(
            receiptBase64: receiptBase64,
            sharedSecret: sharedSecret,
            excludeOldTransactions: excludeOldTransactions,
            completion: completion
        )
    }
    
    class func validate(
        receiptBase64: String,
        sharedSecret: String? = nil,
        excludeOldTransactions: Bool? = nil,
        completion: @escaping (HUMStoreReceiptVerifyResult) -> Void
    ) {
        validate(
            verityType: .production,
            receiptBase64: receiptBase64,
            sharedSecret: sharedSecret,
            excludeOldTransactions: excludeOldTransactions,
            completion: completion
        )
    }
}

extension HUMReceiptValidator {
    private enum ReceiptVerityType: String {
        case production = "https://buy.itunes.apple.com/verifyReceipt"
        case sandbox    = "https://sandbox.itunes.apple.com/verifyReceipt"
    }
    
    private class func validate(
        verityType: ReceiptVerityType,
        receiptBase64: String,
        sharedSecret: String? = nil,
        excludeOldTransactions: Bool? = nil,
        completion: @escaping (HUMStoreReceiptVerifyResult) -> Void
    ) {
        var contents: [String: Any] = ["receipt-data": receiptBase64]
        if let sharedSecret = sharedSecret {
            contents["password"] = sharedSecret
        }
        if let excludeOldTransactions = excludeOldTransactions {
            contents["exclude-old-transactions"] = excludeOldTransactions
        }
        let requestBody: Data
        do {
            requestBody = try JSONSerialization.data(withJSONObject: contents, options: [])
        } catch let e {
            DispatchQueue.main.async {
                completion(.failure(error: .requestBodyEncodeError(error: e)))
            }
            return
        }
        
        let verifyUrl = URL(string: verityType.rawValue)!
        var verifyRequest = URLRequest(url: verifyUrl)
        verifyRequest.httpMethod = "POST"
        verifyRequest.httpBody = requestBody
        let dataTask = URLSession.shared.dataTask(with: verifyRequest) { data, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error: .networkError(error: error)))
                }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(error: .noRemoteData))
                }
                return
            }
            let receiptInfo: HUMStoreReceiptInfo
            do {
                receiptInfo = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves) as? HUMStoreReceiptInfo ?? [:]
            } catch let e {
                let jsonString = String(data: data, encoding: .utf8)
                DispatchQueue.main.async {
                    completion(.failure(error: .jsonDecodeError(error: e, responseString: jsonString)))
                }
                return
            }
            
            guard let status = receiptInfo["status"] as? Int else {
                DispatchQueue.main.async {
                    completion(.failure(error: .receiptInvalid(receipt: receiptInfo, status: .none)))
                }
                return
            }
            let receiptStatus = HUMStoreReceiptStatus(rawValue: status) ?? .unknown
            if receiptStatus == .testReceipt {
                validate(
                    verityType: .sandbox,
                    receiptBase64: receiptBase64,
                    sharedSecret: sharedSecret,
                    excludeOldTransactions: excludeOldTransactions,
                    completion: completion
                )
            } else {
                DispatchQueue.main.async {
                    if receiptStatus == .valid {
                        completion(.success(receiptInfo: receiptInfo))
                    } else {
                        completion(.failure(error: .receiptInvalid(receipt: receiptInfo, status: receiptStatus)))
                    }
                }
            }
        }
        dataTask.resume()
    }
    
}
