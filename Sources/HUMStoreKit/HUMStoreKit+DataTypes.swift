//
//  HUMStoreKit+DataTypes.swift
//  
//
//  Created by huangzhiming on 2022/8/2.
//

import StoreKit

public typealias HUMStoreReceiptInfo = [String: Any]

public enum HUMStoreReceiptStatus: Int {
    case unknown                        = -2
    case none                           = -1
    case valid                          = 0
    /// The request to the App Store was not made using the HTTP POST request method.
    case jsonNotReadable                = 21000
    /// The data in the receipt-data property was malformed or the service experienced a temporary issue. Try again.
    case malformedOrMissingData         = 21002
    /// The receipt could not be authenticated.
    case receiptCouldNotBeAuthenticated = 21003
    /// The shared secret you provided does not match the shared secret on file for your account.
    case secretNotMatching              = 21004
    /// The receipt server was temporarily unable to provide the receipt. Try again.
    case receiptServerUnavailable       = 21005
    /// This receipt is valid but the subscription has expired. When this status code is returned to your server,
    /// the receipt data is also decoded and returned as part of the response. Only returned for iOS 6-style transaction receipts for auto-renewable subscriptions.
    case subscriptionExpired            = 21006
    /// This receipt is from the test environment, but it was sent to the production environment for verification.
    case testReceipt                    = 21007
    /// This receipt is from the production environment, but it was sent to the test environment for verification.
    case productionEnvironment          = 21008
    /// Internal data access error. Try again later.
    case appleInternalDataAccessError   = 21009
    /// The user account cannot be found or has been deleted.
    case userAccountNotFound            = 21010
}

public enum HUMStoreExpirationIntent: String {
    case unknown                        = "-1"
    /// The customer canceled their subscription.
    case customerCancelled              = "1"
    /// Billing error; for example, the customer’s payment information is no longer valid.
    case billingError                   = "2"
    /// The customer didn’t consent to an auto-renewable subscription price increase that requires customer consent, allowing the subscription to expire.
    case customerNotConsentPriceChange  = "3"
    /// The product wasn’t available for purchase at the time of renewal.
    case notAvailable                   = "4"
    /// The subscription expired for some other reason.
    case subscriptionExpired            = "5"
}

public enum HUMStoreReceiptError: Error {
    case noReceiptData
    case noRemoteData
    case requestBodyEncodeError(error: Error)
    case networkError(error: Error)
    case jsonDecodeError(error: Error, responseString: String?)
    case receiptInvalid(receipt: HUMStoreReceiptInfo, status: HUMStoreReceiptStatus)
}

public struct HUMStoreProductResult {
    let products: Set<SKProduct>
    let invalidProductIds: Set<String>
}

public struct HUMStorePaymentDiscount {
    let discount: Any?
    
    @available(iOS 12.2, tvOS 12.2, OSX 10.14.4, watchOS 6.2, macCatalyst 13.0, *)
    public init(discount: SKPaymentDiscount) {
        self.discount = discount
    }
    
    private init() {
        self.discount = nil
    }
}

public enum HUMStoreTransactionResult {
    case purchased(transaction: SKPaymentTransaction)
    case restored(transaction: SKPaymentTransaction)
    case deferred(transaction: SKPaymentTransaction)
    case failed(transaction: SKPaymentTransaction, error: NSError)
    case cancelled(transaction: SKPaymentTransaction)
}

public enum HUMStorePurchaseResult {
    case success(transaction: SKPaymentTransaction, receiptData: Data, receiptValidateResult: HUMStoreReceiptInfo)
    case deferred(transaction: SKPaymentTransaction)
    case cancelled(transaction: SKPaymentTransaction)
    case failed(transaction: SKPaymentTransaction, error: Error)
    case productFailed(productId: String, error: Error)
}

public enum HUMStoreReceiptVerifyResult {
    case success(receiptInfo: HUMStoreReceiptInfo)
    case failure(error: HUMStoreReceiptError)
}

// MARK: internal
struct HUMStorePayment {
    let product: SKProduct
    let paymentDiscount: HUMStorePaymentDiscount?
    let quantity: Int
    let applicationUsername: String
}
