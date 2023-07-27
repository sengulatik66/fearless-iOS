import Foundation
import SSFModels

protocol AccountInfoFetchingProtocol {
    var supportSubscribing: Bool { get }

    func fetch(
        for chainAsset: ChainAsset,
        accountId: AccountId,
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
    )

    func fetch(
        for chainAssets: [ChainAsset],
        wallet: MetaAccountModel,
        completionBlock: @escaping ([ChainAsset: AccountInfo?]) -> Void
    )
}
