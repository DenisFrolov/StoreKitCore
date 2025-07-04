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

    public var weekPrice: Decimal? {
        if #available(iOS 16.4, *) {
            switch subscription?.subscriptionPeriod {
            case .everyThreeDays:   return nil
            case .weekly:           return nil
            case .everyTwoWeeks:    return price / 2
            case .monthly:          return price / 4
            case .everyTwoMonths:   return price / 8
            case .everyThreeMonths: return price / 12
            case .everySixMonths:   return price / 24
            case .yearly:           return price / 48
            case .none:             return nil
            case .some(_):          return nil
            }
        } else {
            return nil
        }
    }

    public var weekPriceFormatted: String? {
        guard let weekPrice = weekPrice else { return nil }
        return priceFormatStyle.format(weekPrice)
    }

    public var promoPeriod: String? {
        guard let intro =  subscription?.introductoryOffer else { return nil }
        return intro.period.formatted(subscriptionPeriodFormatStyle, referenceDate: .now)
    }
}
