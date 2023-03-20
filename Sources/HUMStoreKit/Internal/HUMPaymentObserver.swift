//
//  HUMStoreKitObserver.swift
//  
//
//  Created by huangzhiming on 2022/7/26.
//

import StoreKit

final class HUMPaymentObserver: NSObject {
    typealias PaymentCallback = (HUMStoreTransactionResult) -> Void
    typealias RestoreCallback = (Error?) -> Void
    
    static let shared = HUMPaymentObserver()
    
    private let serialQueue = DispatchQueue(label: String(describing: HUMPaymentObserver.self))
    private var paymentHandlers: [String: [PaymentCallback]] = [:]
    private var fallbackPaymentHandler: PaymentCallback?
    private var restoreHandlers: [RestoreCallback] = []
    
    deinit {
        handleAppWillTerminate()
    }
    
    private override init() {
        super.init()
        SKPaymentQueue.default().add(self)
        
        #if !os(watchOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        #endif
    }
    
    @objc private func handleAppWillTerminate() {
        SKPaymentQueue.default().remove(self)
        NotificationCenter.default.removeObserver(self)
    }
    
}

extension HUMPaymentObserver {
    func canMakePayments() -> Bool {
        return SKPaymentQueue.canMakePayments()
    }
    
    func start(payment: HUMStorePayment, completion: @escaping PaymentCallback) {
        let skPayment = SKMutablePayment(product: payment.product)
        skPayment.quantity = payment.quantity
        skPayment.applicationUsername = payment.applicationUsername
        if #available(iOS 12.2, tvOS 12.2, OSX 10.14.4, watchOS 6.2, *) {
            if let discount = payment.paymentDiscount?.discount as? SKPaymentDiscount {
                skPayment.paymentDiscount = discount
            }
        }
        
        serialQueue.async { [weak self] in
            let productId = payment.product.productIdentifier
            var handlers = self?.paymentHandlers[productId] ?? []
            handlers.append(completion)
            self?.paymentHandlers[productId] = handlers
            
            DispatchQueue.main.async {
                SKPaymentQueue.default().add(skPayment)
            }
        }
    }
    
    func set(fallbackPaymentHandler: @escaping PaymentCallback) {
        self.fallbackPaymentHandler = fallbackPaymentHandler
    }
    
    func restoreCompletedTransactions(handler: @escaping RestoreCallback) {
        serialQueue.async { [weak self] in
            self?.restoreHandlers.append(handler)
            DispatchQueue.main.async {
                SKPaymentQueue.default().restoreCompletedTransactions()
            }
        }
    }
    
    func finish(transaction: SKPaymentTransaction) {
        SKPaymentQueue.default().finishTransaction(transaction)
    }
}

extension HUMPaymentObserver: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            let result: HUMStoreTransactionResult
            switch transaction.transactionState {
            case .purchasing:
                continue
            case .purchased:
                result = .purchased(transaction: transaction)
            case .restored:
                result = .restored(transaction: transaction)
            case .deferred:
                result = .deferred(transaction: transaction)
            case .failed:
                if let error = transaction.error as NSError? {
                    if error.domain == SKErrorDomain, error.code == SKError.Code.paymentCancelled.rawValue {
                        result = .cancelled(transaction: transaction)
                    } else {
                        result = .failed(transaction: transaction, error: error)
                    }
                } else {
                    let error = NSError.iap(code: .unknown, reason: "Unknown error occurred")
                    result = .failed(transaction: transaction, error: error)
                }
            @unknown default:
                continue
            }
            
            serialQueue.async { [weak self] in
                let productId = transaction.payment.productIdentifier
                if let handlers = self?.paymentHandlers.removeValue(forKey: productId), !handlers.isEmpty {
                    DispatchQueue.main.async {
                        handlers.forEach { $0(result) }
                    }
                } else {
                    let handler = self?.fallbackPaymentHandler
                    DispatchQueue.main.async {
                        handler?(result)
                    }
                }
            }
        }
    }

    // Sent when all transactions from the user's purchase history have successfully been added back to the queue.
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        serialQueue.async { [weak self] in
            let handlers = self?.restoreHandlers ?? []
            self?.restoreHandlers = []
            
            DispatchQueue.main.async {
                handlers.forEach { $0(nil) }
            }
        }
    }
    
    // Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        serialQueue.async { [weak self] in
            let handlers = self?.restoreHandlers ?? []
            self?.restoreHandlers = []
            
            DispatchQueue.main.async {
                handlers.forEach { $0(error) }
            }
        }
    }
    
}
