import UIKit
import RobinHood

final class ManageAssetsInteractor {
    weak var presenter: ManageAssetsInteractorOutputProtocol?

    private var selectedMetaAccount: MetaAccountModel {
        didSet {
            presenter?.didReceiveWallet(selectedMetaAccount)
        }
    }

    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let operationQueue: OperationQueue
    private let eventCenter: EventCenterProtocol

    private var assetIdsEnabled: [String]?
    private var sortKeys: [String]?
    private var filterOptions: [FilterOption]?

    init(
        selectedMetaAccount: MetaAccountModel,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chainRepository = chainRepository
        self.accountRepository = accountRepository
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
    }

    private func fetchChainsAndSubscribeBalance() {
        let fetchOperation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())

        fetchOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.handleChains(result: fetchOperation.result)
            }
        }

        operationQueue.addOperation(fetchOperation)
    }

    private func handleChains(result: Result<[ChainModel], Error>?) {
        switch result {
        case let .success(chains):
            subscribeToAccountInfo(for: chains)
            presenter?.didReceiveChains(result: .success(chains))
        case let .failure(error):
            presenter?.didReceiveChains(result: .failure(error))
        case .none:
            presenter?.didReceiveChains(result: .failure(BaseOperationError.parentOperationCancelled))
        }
    }

    private func subscribeToAccountInfo(for chains: [ChainModel]) {
        let chainsAssets = chains.map(\.chainAssets).reduce([], +)
        accountInfoSubscriptionAdapter.subscribe(chainsAssets: chainsAssets, handler: self)
    }

    private func save(
        _ updatedAccount: MetaAccountModel,
        needDismiss: Bool
    ) {
        let saveOperation = accountRepository.saveOperation {
            [updatedAccount]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            if needDismiss {
                DispatchQueue.main.async {
                    self?.presenter?.saveDidComplete()
                }
            }
            SelectedWalletSettings.shared.performSave(value: updatedAccount) { result in
                switch result {
                case let .success(account):
                    DispatchQueue.main.async {
                        self?.selectedMetaAccount = account
                        self?.eventCenter.notify(with: MetaAccountModelChangedEvent(account: account))
                    }
                case .failure:
                    break
                }
            }
        }

        operationQueue.addOperation(saveOperation)
    }
}

extension ManageAssetsInteractor: ManageAssetsInteractorInputProtocol {
    func markUnused(chain: ChainModel) {
        var unusedChainIds = selectedMetaAccount.unusedChainIds ?? []
        unusedChainIds.append(chain.chainId)
        let updatedAccount = selectedMetaAccount.replacingUnusedChainIds(unusedChainIds)

        save(updatedAccount, needDismiss: false)
    }

    func saveFilter(_ options: [FilterOption]) {
        filterOptions = options
        presenter?.didReceiveFilterOptions(filterOptions)
    }

    func setup() {
        fetchChainsAndSubscribeBalance()
        presenter?.didReceiveAccount(selectedMetaAccount)
    }

    func saveAssetsOrder(assets: [ChainAsset]) {
        let keys = assets.map { $0.uniqueKey(accountId: selectedMetaAccount.substrateAccountId) }
        sortKeys = keys

        presenter?.didReceiveSortOrder(keys)
    }

    func saveAssetIdsEnabled(_ assetIdsEnabled: [String]) {
        self.assetIdsEnabled = assetIdsEnabled

        presenter?.didReceiveAssetIdsEnabled(assetIdsEnabled)
    }

    func saveAllChanges() {
        var updatedAccount: MetaAccountModel?

        if let keys = sortKeys, keys != selectedMetaAccount.assetKeysOrder {
            updatedAccount = selectedMetaAccount.replacingAssetKeysOrder(keys)
        }

        if let assetIdsEnabled = assetIdsEnabled, assetIdsEnabled != selectedMetaAccount.assetIdsEnabled {
            updatedAccount = selectedMetaAccount.replacingAssetIdsEnabled(assetIdsEnabled)
        }

        if let filterOptions = filterOptions, filterOptions != selectedMetaAccount.assetFilterOptions {
            updatedAccount = selectedMetaAccount.replacingAssetsFilterOptions(filterOptions)
        }

        if let updatedAccount = updatedAccount {
            save(updatedAccount, needDismiss: true)
        }
    }
}

extension ManageAssetsInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainAsset: ChainAsset
    ) {
        presenter?.didReceiveAccountInfo(result: result, for: chainAsset.uniqueKey(accountId: accountId))
    }
}
