//
//  HUMReceiptRequest.swift
//  
//
//  Created by huangzhiming on 2022/8/3.
//

import StoreKit

final class HUMReceiptRequest: NSObject {
    typealias RequestCallback = (Result<Data, Error>) -> Void
    
    private let serialQueue = DispatchQueue(label: String(describing: HUMReceiptRequest.self))
    private var request: SKReceiptRefreshRequest?
    private var callbacks: [RequestCallback] = []
    
    private var appStoreReceiptData: Data? {
        guard let receiptUrl = Bundle.main.appStoreReceiptURL,
              let data = try? Data(contentsOf: receiptUrl) else {
                  return nil
              }
        return data
    }
    
    deinit {
        request?.delegate = nil
        request = nil
    }
    
    func fetchReceiptData(
        forceRefresh: Bool = false,
        sandboxReceiptProperties: [String: Any]? = nil,
        completion: RequestCallback?
    ) {
        let receiptData = appStoreReceiptData
        if let receiptData = receiptData, !forceRefresh {
            completion?(.success(receiptData))
            return
        }
        
        serialQueue.async { [weak self] in
            if self?.request == nil {
                let request = SKReceiptRefreshRequest(receiptProperties: sandboxReceiptProperties)
                request.delegate = self
                self?.request = request
            }
            if let completion = completion {
                self?.callbacks.append(completion)
            }
            DispatchQueue.main.async {
                self?.request?.start()
            }
        }
    }
    
}

extension HUMReceiptRequest: SKRequestDelegate {
    func requestDidFinish(_ request: SKRequest) {
        serialQueue.async { [weak self] in
            let callbacks = self?.callbacks ?? []
            self?.request = nil
            self?.callbacks = []
            
            if let receiptData = self?.appStoreReceiptData {
                DispatchQueue.main.async {
                    callbacks.forEach {
                        $0(.success(receiptData))
                    }
                }
            } else {
                DispatchQueue.main.async {
                    let error = NSError.iap(code: .unknown, reason: "Receipt read failed from Bundle.main.appStoreReceiptURL")
                    callbacks.forEach {
                        $0(.failure(error))
                    }
                }
            }
        }
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        serialQueue.async { [weak self] in
            let callbacks = self?.callbacks ?? []
            self?.request = nil
            self?.callbacks = []
            
            DispatchQueue.main.async {
                callbacks.forEach {
                    $0(.failure(error))
                }
            }
        }
    }
}
