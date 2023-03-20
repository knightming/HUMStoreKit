import StoreKit

public class HUMStoreKit {
    public typealias ReceiptValidateCallback = (
        _ transaction: SKPaymentTransaction,
        _ receiptData: Data,
        _ completion: ((Error?) -> Void)?
    ) -> Void
    
    private static let shared = HUMStoreKit()
    
    private let paymentObserver: HUMPaymentObserver
    private let productProvider: HUMProductProvider
    private let receiptRequest: HUMReceiptRequest
    
    private init() {
        paymentObserver = HUMPaymentObserver.shared
        productProvider = HUMProductProvider()
        receiptRequest = HUMReceiptRequest()
    }
}

// MARK: Private
extension HUMStoreKit {
    private func retrieveProductInfo(
        productIds: Set<String>,
        completion: @escaping (Result<Set<SKProduct>, Error>) -> Void
    ) {
        productProvider.retrieveProductInfo(productIds: productIds) { result in
            switch result {
            case let .success(result):
                completion(.success(result.products))
            case let .failure(error):
                completion(.failure(error as NSError))
            }
        }
    }
}

extension HUMStoreKit {
    private func purchaseAndValidate(
        productId: String,
        quantity: Int = 1,
        applicationUesrname: String = "",
        forceRefreshReceipt: Bool = false,
        excludeOldTransactions: Bool = false,
        paymentDiscount: HUMStorePaymentDiscount? = nil,
        sharedSecret: String?,
        completion: @escaping (HUMStorePurchaseResult) -> Void
    ) {
        retrieveProductInfo(productIds: [productId]) { result in
            switch result {
            case let .success(products):
                if let product = products.first {
                    self.purchaseAndValidate(
                        product: product,
                        quantity: quantity,
                        applicationUsername: applicationUesrname,
                        paymentDiscount: paymentDiscount,
                        sharedSecret: sharedSecret,
                        completion: completion
                    )
                } else {
                    let error = NSError.iap(code: .unknown, reason: "SKProduct query failed")
                    completion(.productFailed(
                        productId: productId,
                        error: error
                    ))
                }
            case let .failure(error):
                completion(.productFailed(
                    productId: productId,
                    error: error
                ))
            }
        }
    }
    
    private func purchaseAndValidate(
        product: SKProduct,
        quantity: Int,
        applicationUsername: String = "",
        forceRefreshReceipt: Bool = false,
        excludeOldTransactions: Bool = false,
        paymentDiscount: HUMStorePaymentDiscount? = nil,
        sharedSecret: String?,
        completion: @escaping (HUMStorePurchaseResult) -> Void
    ) {
        let payment = HUMStorePayment(
            product: product,
            paymentDiscount: paymentDiscount,
            quantity: quantity,
            applicationUsername: applicationUsername
        )
        paymentObserver.start(payment: payment) { [weak self] result in
            switch result {
            case let .purchased(transaction: transaction):
                fallthrough
            case let .restored(transaction: transaction):
                self?.receiptRequest.fetchReceiptData(
                    forceRefresh: forceRefreshReceipt,
                    sandboxReceiptProperties: nil
                ) { result in
                    switch result {
                    case let .success(receiptData):
                        HUMReceiptValidator.validate(
                            receiptData: receiptData,
                            sharedSecret: sharedSecret,
                            excludeOldTransactions: excludeOldTransactions
                        ) { result in
                            switch result {
                            case let .success(receiptInfo):
                                SKPaymentQueue.default().finishTransaction(transaction)
                                completion(.success(
                                    transaction: transaction,
                                    receiptData: receiptData,
                                    receiptValidateResult: receiptInfo
                                ))
                            case let .failure(error):
                                completion(.failed(transaction: transaction, error: error))
                            }
                        }
                        break
                    case let .failure(error):
                        completion(.failed(transaction: transaction, error: error))
                    }
                }
            case let .deferred(transaction: transaction):
                completion(.deferred(transaction: transaction))
            case let .failed(transaction: transaction, error: error):
                completion(.failed(transaction: transaction, error: error))
            case let .cancelled(transaction: transaction):
                completion(.cancelled(transaction: transaction))
            }
        }
    }
    
    private func purchaseWithValidator(
        productId: String,
        quantity: Int = 1,
        applicationUsername: String = "",
        paymentDiscount: HUMStorePaymentDiscount? = nil,
        forceRefreshReceipt: Bool = false,
        validator: @escaping ReceiptValidateCallback,
        completion: @escaping (HUMStorePurchaseResult) -> Void
    ) {
        retrieveProductInfo(productIds: [productId]) { result in
            switch result {
            case let .success(products):
                if let product = products.first {
                    self.purchaseWithValidator(
                        product: product,
                        quantity: quantity,
                        applicationUsername: applicationUsername,
                        paymentDiscount: paymentDiscount,
                        forceRefreshReceipt: forceRefreshReceipt,
                        validator: validator,
                        completion: completion
                    )
                } else {
                    let error = NSError.iap(code: .unknown, reason: "SKProduct query failed")
                    completion(.productFailed(
                        productId: productId,
                        error: error
                    ))
                }
            case let .failure(error):
                completion(.productFailed(
                    productId: productId,
                    error: error
                ))
            }
        }
    }
    
    private func purchaseWithValidator(
        product: SKProduct,
        quantity: Int,
        applicationUsername: String = "",
        paymentDiscount: HUMStorePaymentDiscount? = nil,
        forceRefreshReceipt: Bool = false,
        validator: @escaping ReceiptValidateCallback,
        completion: @escaping (HUMStorePurchaseResult) -> Void
    ) {
        let payment = HUMStorePayment(
            product: product,
            paymentDiscount: paymentDiscount,
            quantity: quantity,
            applicationUsername: applicationUsername
        )
        paymentObserver.start(payment: payment) { [weak self] result in
            switch result {
            case let .purchased(transaction: transaction):
                fallthrough
            case let .restored(transaction: transaction):
                self?.receiptRequest.fetchReceiptData(
                    forceRefresh: forceRefreshReceipt,
                    sandboxReceiptProperties: nil
                ) { result in
                    switch result {
                    case let .success(receiptData):
                        validator(transaction, receiptData) { error in
                            if let error = error {
                                completion(.failed(
                                    transaction: transaction,
                                    error: error
                                ))
                            } else {
                                SKPaymentQueue.default().finishTransaction(transaction)
                                completion(.success(
                                    transaction: transaction,
                                    receiptData: receiptData,
                                    receiptValidateResult: [:]
                                ))
                            }
                        }
                    case let .failure(error):
                        completion(.failed(transaction: transaction, error: error))
                    }
                }
            case let .deferred(transaction: transaction):
                completion(.deferred(transaction: transaction))
            case let .failed(transaction, error):
                completion(.failed(transaction: transaction, error: error))
            case let .cancelled(transaction):
                completion(.cancelled(transaction: transaction))
            }
        }
    }
}

// MARK: Public
extension HUMStoreKit {
    /// 返回当前用户是否允许使用IAP
    public class var canMakePayments: Bool {
        return HUMStoreKit.shared.paymentObserver.canMakePayments()
    }
    
    /// 设置默认内购处理
    public class func set(fallbackPaymentHandler: @escaping (HUMStoreTransactionResult) -> Void) {
        HUMStoreKit.shared.paymentObserver.set(fallbackPaymentHandler: fallbackPaymentHandler)
    }
    
    /// 获取指定productIds对应的SKProduct
    public class func retrieveProductInfo(
        productIds: Set<String>,
        completion: @escaping (Result<Set<SKProduct>, Error>) -> Void
    ) {
        HUMStoreKit.shared.retrieveProductInfo(
            productIds: productIds,
            completion: completion
        )
    }
    
    /// 获取receiptData
    public class func fetchReceiptData(
        forceRefresh: Bool = false,
        sandboxReceiptProperties: [String: Any]? = nil,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        HUMStoreKit.shared.receiptRequest.fetchReceiptData(
            forceRefresh: forceRefresh,
            sandboxReceiptProperties: sandboxReceiptProperties,
            completion: completion
        )
    }
    
    /// 直接向Apple服务器请求验证订单
    public class func validate(
        receiptData: Data,
        sharedSecret: String? = nil,
        excludeOldTransactions: Bool? = nil,
        completion: @escaping (HUMStoreReceiptVerifyResult) -> Void
    ) {
        HUMReceiptValidator.validate(
            receiptData: receiptData,
            sharedSecret: sharedSecret,
            excludeOldTransactions: excludeOldTransactions,
            completion: completion
        )
    }
    
    public class func validate(
        receiptBase64: String,
        sharedSecret: String? = nil,
        excludeOldTransactions: Bool? = nil,
        completion: @escaping (HUMStoreReceiptVerifyResult) -> Void
    ) {
        HUMReceiptValidator.validate(
            receiptBase64: receiptBase64,
            sharedSecret: sharedSecret,
            excludeOldTransactions: excludeOldTransactions,
            completion: completion
        )
    }
    
    /// 购买给定productId商品，并使用App端订单验证
    public class func purchaseWithInternalReceiptValidator(
        productId: String,
        quantity: Int = 1,
        applicationUesrname: String = "",
        forceRefreshReceipt: Bool = false,
        excludeOldTransactions: Bool = false,
        paymentDiscount: HUMStorePaymentDiscount? = nil,
        sharedSecret: String?,
        completion: @escaping (HUMStorePurchaseResult) -> Void
    ) {
        HUMStoreKit.shared.purchaseAndValidate(
            productId: productId,
            quantity: quantity,
            applicationUesrname: applicationUesrname,
            forceRefreshReceipt: forceRefreshReceipt,
            excludeOldTransactions: excludeOldTransactions,
            paymentDiscount: paymentDiscount,
            sharedSecret: sharedSecret,
            completion: completion
        )
    }
    
    /// 购买给定SKProduct商品，并使用App端订单验证
    public class func purchaseWithInternalReceiptValidator(
        product: SKProduct,
        quantity: Int,
        applicationUsername: String = "",
        forceRefreshReceipt: Bool = false,
        excludeOldTransactions: Bool = false,
        paymentDiscount: HUMStorePaymentDiscount? = nil,
        sharedSecret: String?,
        completion: @escaping (HUMStorePurchaseResult) -> Void
    ) {
        HUMStoreKit.shared.purchaseAndValidate(
            product: product,
            quantity: quantity,
            applicationUsername: applicationUsername,
            forceRefreshReceipt: forceRefreshReceipt,
            excludeOldTransactions: excludeOldTransactions,
            paymentDiscount: paymentDiscount,
            sharedSecret: sharedSecret,
            completion: completion
        )
    }
    
    /// 购买给定productId商品，并使用自定义订单验证
    public class func purchaseWithCustomReceiptValidator(
        productId: String,
        quantity: Int = 1,
        applicationUsername: String = "",
        paymentDiscount: HUMStorePaymentDiscount? = nil,
        forceRefreshReceipt: Bool = false,
        validator: @escaping ReceiptValidateCallback,
        completion: @escaping (HUMStorePurchaseResult) -> Void
    ) {
        HUMStoreKit.shared.purchaseWithValidator(
            productId: productId,
            quantity: quantity,
            applicationUsername: applicationUsername,
            paymentDiscount: paymentDiscount,
            forceRefreshReceipt: forceRefreshReceipt,
            validator: validator,
            completion: completion
        )
    }
    
    /// 购买给定SKProduct商品，并使用自定义订单验证
    public class func purchaseWithCustomReceiptValidator(
        product: SKProduct,
        quantity: Int = 1,
        applicationUesrname: String = "",
        paymentDiscount: HUMStorePaymentDiscount? = nil,
        forceRefreshReceipt: Bool = false,
        validator: @escaping ReceiptValidateCallback,
        completion: @escaping (HUMStorePurchaseResult) -> Void
    ) {
        HUMStoreKit.shared.purchaseWithValidator(
            product: product,
            quantity: quantity,
            applicationUsername: applicationUesrname,
            paymentDiscount: paymentDiscount,
            forceRefreshReceipt: forceRefreshReceipt,
            validator: validator,
            completion: completion
        )
    }
    
    /// 结束指定内购Transaction
    public class func finish(transaction: SKPaymentTransaction) {
        HUMStoreKit.shared.paymentObserver.finish(transaction: transaction)
    }
    
    /// 恢复购买
    public class func restoreCompletedTransactions(completion: @escaping (Error?) -> Void) {
        HUMStoreKit.shared.paymentObserver.restoreCompletedTransactions(handler: completion)
    }
}
