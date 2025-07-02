import StoreKit

extension Product {
    public var localizedPrice: String {
        return priceFormatStyle.format(price)
    }

    public var isSubscription: Bool {
        return type == .autoRenewable || type == .nonRenewable
    }

    public var subscriptionPeriod: String? {
        guard let subscription = subscription else { return nil }

        let period = subscription.subscriptionPeriod
        let unit = period.unit
        let value = period.value

        switch unit {
        case .day:
            return value == 1 ? "Daily" : "\(value) days"
        case .week:
            return value == 1 ? "Weekly" : "\(value) weeks"
        case .month:
            return value == 1 ? "Monthly" : "\(value) months"
        case .year:
            return value == 1 ? "Yearly" : "\(value) years"
        @unknown default:
            return nil
        }
    }
}
