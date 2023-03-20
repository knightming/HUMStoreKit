//
//  HUMStoreKit+Extension.swift
//  
//
//  Created by huangzhiming on 2022/8/3.
//

import StoreKit

extension NSError {
    static func iap(code: SKError.Code, reason: String) -> NSError{
        return NSError(domain: SKErrorDomain, code: code.rawValue, userInfo: [NSLocalizedDescriptionKey: reason])
    }
}

public extension SKProduct {
    var localizedPrice: String? {
        return priceFormatter(local: priceLocale).string(from: price)
    }
    
    // 根据比例系数将价格换算为当地价格
    func localizedOriginPrice(factor: Double) -> String? {
        let priceString = factor * self.price.doubleValue
        let decimal = NSDecimalNumber(string: "\(priceString)")
        return priceFormatter(local: priceLocale).string(from: decimal)
    }
    
    // 换算为月均价格
    func monthlyPrice(months: Int) -> String? {
        let priceString = self.price.doubleValue / Double(months)
        let decimal = NSDecimalNumber(string: "\(priceString)")
        return priceFormatter(local: priceLocale).string(from: decimal)
    }
    
    @available(iOSApplicationExtension 11.2, iOS 13, OSX 10.13.2, tvOS 11.2, watchOS 6.2, macCatalyst 13.0, *)
    var localizedSubscriptionPeriod: String {
        guard let subscriptionPeriod = self.subscriptionPeriod else {
            return ""
        }
        let dateComponents: DateComponents
        switch subscriptionPeriod.unit {
        case .day:
            dateComponents = DateComponents(day: subscriptionPeriod.numberOfUnits)
        case .week:
            dateComponents = DateComponents(weekOfMonth: subscriptionPeriod.numberOfUnits)
        case .month:
            dateComponents = DateComponents(month: subscriptionPeriod.numberOfUnits)
        case .year:
            dateComponents = DateComponents(year: subscriptionPeriod.numberOfUnits)
        @unknown default:
            print("[WARNING]: SKProduct subscriptionPeriod.unit update, NEED FIX!")
            dateComponents = DateComponents(month: subscriptionPeriod.numberOfUnits)
        }
        return DateComponentsFormatter.localizedString(from: dateComponents, unitsStyle: .short) ?? ""
    }
    
    private func priceFormatter(local: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = local
        formatter.numberStyle = .currency
        return formatter
    }
}

@available(iOSApplicationExtension 11.2, iOS 11.2, OSX 10.13.2, tvOS 11.2, watchOS 4.2, macCatalyst 13.0, *)
public extension SKProductDiscount {
    var localizedPrice: String? {
        return priceFormatter(local: priceLocale).string(from: price)
    }
    
    var localizedSubscriptionPeriod: String {
        let dateComponents: DateComponents
        switch subscriptionPeriod.unit {
        case .day:
            dateComponents = DateComponents(day: subscriptionPeriod.numberOfUnits)
        case .week:
            dateComponents = DateComponents(weekOfMonth: subscriptionPeriod.numberOfUnits)
        case .month:
            dateComponents = DateComponents(month: subscriptionPeriod.numberOfUnits)
        case .year:
            dateComponents = DateComponents(year: subscriptionPeriod.numberOfUnits)
        @unknown default:
            print("[WARNING]: SKProductDiscount subscriptionPeriod.unit update, NEED FIX!")
            dateComponents = DateComponents(month: subscriptionPeriod.numberOfUnits)
        }
        return DateComponentsFormatter.localizedString(from: dateComponents, unitsStyle: .short) ?? ""
    }
    
    private func priceFormatter(local: Locale) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = local
        formatter.numberStyle = .currency
        return formatter
    }
}
