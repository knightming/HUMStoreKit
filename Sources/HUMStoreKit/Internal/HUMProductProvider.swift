//
//  HUMProductProvider.swift
//  
//
//  Created by Henry on 2022/8/3.
//

import StoreKit

class HUMProductProvider: NSObject {
    private let serialQueue = DispatchQueue(label: String(describing: HUMProductProvider.self))
    private var inflightRequests: [String: HUMProductInfoRequest] = [:]
    
    func retrieveProductInfo(
        productIds: Set<String>,
        completion: @escaping HUMProductInfoRequest.RequestCallback
    ) {
        let requestId = UUID().uuidString
        let request = HUMProductInfoRequest(
            requestId: requestId,
            productIds: productIds,
            callback: completion,
            delegate: self
        )
        serialQueue.async { [weak self] in
            self?.inflightRequests[requestId] = request
            DispatchQueue.main.async {
                request.start()
            }
        }
    }
}

extension HUMProductProvider: HUMProductInfoRequestDelegate {
    func productRequestDidFinish(requestId: String, result: Result<HUMStoreProductResult, Error>) {
        serialQueue.async { [weak self] in
            let request = self?.inflightRequests.removeValue(forKey: requestId)
            DispatchQueue.main.async {
                request?.callback(result)
            }
        }
    }
}
