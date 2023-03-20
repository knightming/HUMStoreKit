//
//  HUMProductInfoRequest.swift
//  
//
//  Created by huangzhiming on 2022/8/3.
//

import StoreKit

protocol HUMProductInfoRequestDelegate: NSObjectProtocol {
    func productRequestDidFinish(requestId: String, result: Result<HUMStoreProductResult, Error>)
}

class HUMProductInfoRequest: NSObject {
    typealias RequestCallback = (Result<HUMStoreProductResult, Error>) -> Void
    
    private let requestId: String
    private let request: SKProductsRequest
    private weak var delegate: HUMProductInfoRequestDelegate?
    
    let callback: RequestCallback
    
    deinit {
        request.delegate = nil
        print("HUMProductInfoRequest with \(requestId) deinit")
    }
    
    init(requestId: String, productIds: Set<String>, callback: @escaping RequestCallback, delegate: HUMProductInfoRequestDelegate) {
        self.requestId = requestId
        self.request = SKProductsRequest(productIdentifiers: productIds)
        self.callback = callback
        self.delegate = delegate
        super.init()
        request.delegate = self
    }
    
    func start() {
        request.start()
    }
}

extension HUMProductInfoRequest: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        let products = Set<SKProduct>(response.products)
        let invalidProductIds = Set<String>(response.invalidProductIdentifiers)
        let result = HUMStoreProductResult(products: products, invalidProductIds: invalidProductIds)
        
        self.delegate?.productRequestDidFinish(requestId: requestId, result: .success(result))
    }
    
    func requestDidFinish(_ request: SKRequest) {
        
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        self.delegate?.productRequestDidFinish(requestId: requestId, result: .failure(error))
    }
}
