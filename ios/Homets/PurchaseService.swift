import Observation
import StoreKit

@MainActor @Observable
final class PurchaseService {
    static let productID = "com.addvalue.homets.premium.yearly"
    private(set) var product: Product?
    private(set) var isPremium = false
    private(set) var isBusy = false
    var errorMessage: String?
    var priceText: String { product?.displayPrice ?? "₩29,000" }

    func refresh() async {
        do { product = try await Product.products(for: [Self.productID]).first; isPremium = await hasEntitlement() }
        catch { errorMessage = tr("구독 정보를 불러오지 못했습니다.") }
    }
    func purchase() async {
        if product == nil {
            do { product = try await Product.products(for: [Self.productID]).first }
            catch { errorMessage = tr("구독 정보를 불러오지 못했습니다."); return }
        }
        guard let product else { errorMessage = tr("구독 상품을 불러오지 못했습니다."); return }
        isBusy = true; defer { isBusy = false }
        do {
            switch try await product.purchase() {
            case .success(let result): let transaction = try verified(result); await transaction.finish(); isPremium = true
            case .pending: errorMessage = tr("구매 승인을 기다리고 있습니다.")
            case .userCancelled: break
            @unknown default: break
            }
        } catch { errorMessage = tr("구매를 완료하지 못했습니다.") }
    }
    func restore() async {
        isBusy = true; defer { isBusy = false }
        do { try await AppStore.sync(); isPremium = await hasEntitlement(); if !isPremium { errorMessage = tr("복원할 구독이 없습니다.") } }
        catch { errorMessage = tr("구매 복원에 실패했습니다.") }
    }
    private func hasEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? verified(result), transaction.productID == Self.productID, transaction.revocationDate == nil { return true }
        }
        return false
    }
    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result { case .verified(let value): return value; case .unverified: throw StoreError.unverified }
    }
    private enum StoreError: Error { case unverified }
}
