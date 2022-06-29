import UIKit
import RobinHood
import IrohaCrypto
import SoraFoundation
import SoraKeystore

final class ChainAccountBalanceListInteractor {
    weak var presenter: ChainAccountBalanceListInteractorOutputProtocol?

    private var selectedMetaAccount: MetaAccountModel
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let assetRepository: AnyDataProviderRepository<AssetModel>
    private var accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let operationQueue: OperationQueue
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let eventCenter: EventCenterProtocol
    private let metaAccountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let jsonDataProviderFactory: JsonDataProviderFactoryProtocol

    private var chains: [ChainModel]?

    private var pricesProvider: AnySingleValueProvider<[PriceData]>?
    private var fiatInfoProvider: AnySingleValueProvider<[Currency]>?
    private lazy var currency: Currency = {
        selectedMetaAccount.selectedCurrency
    }()

    init(
        selectedMetaAccount: MetaAccountModel,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        assetRepository: AnyDataProviderRepository<AssetModel>,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        operationQueue: OperationQueue,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        eventCenter: EventCenterProtocol,
        metaAccountRepository: AnyDataProviderRepository<MetaAccountModel>,
        jsonDataProviderFactory: JsonDataProviderFactoryProtocol
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chainRepository = chainRepository
        self.assetRepository = assetRepository
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.operationQueue = operationQueue
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.eventCenter = eventCenter
        self.metaAccountRepository = metaAccountRepository
        self.jsonDataProviderFactory = jsonDataProviderFactory
    }

    private func fetchChainsAndSubscribeBalance() {
        let fetchOperation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())

        fetchOperation.completionBlock = { [weak self] in
            self?.handleChains(result: fetchOperation.result)
        }

        operationQueue.addOperation(fetchOperation)
    }

    private func handleChains(result: Result<[ChainModel], Error>?) {
        switch result {
        case let .success(chains):
            self.chains = chains
            subscribeToAccountInfo(for: chains)
            DispatchQueue.main.async {
                self.presenter?.didReceiveChains(result: .success(chains))
            }
            subscribeToPrice(for: chains)
        case let .failure(error):
            presenter?.didReceiveChains(result: .failure(error))
        case .none:
            presenter?.didReceiveChains(result: .failure(BaseOperationError.parentOperationCancelled))
        }
    }

    private func subscribeToPrice(for chains: [ChainModel]) {
        var pricesIds: [AssetModel.PriceId] = []
        var pricesData: [PriceData] = []

        let chainAssets = chains.map(\.chainAssets).reduce([], +)
        chainAssets.forEach { chainAsset in
            if let priceId = chainAsset.asset.priceId {
                pricesIds.append(priceId)

                if let price = chainAsset.asset.price {
                    let priceData = PriceData(
                        priceId: priceId,
                        price: String(describing: price),
                        fiatDayChange: chainAsset.asset.fiatDayChange
                    )
                    pricesData.append(priceData)
                }
            } else {
                let emptyPrice = PriceData(
                    priceId: chainAsset.asset.id,
                    price: "",
                    fiatDayChange: nil
                )
                pricesData.append(emptyPrice)
            }
        }

        DispatchQueue.main.async {
            self.presenter?.didReceivePricesData(result: .success(pricesData))
        }
        pricesProvider = subscribeToPrices(for: pricesIds)
    }

    private func subscribeToAccountInfo(for chains: [ChainModel]) {
        let chainAssets = chains.map(\.chainAssets).reduce([], +)
        accountInfoSubscriptionAdapter.subscribe(chainsAssets: chainAssets, handler: self)

        let accountInfos = chainAssets.reduce(into: [ChainAssetKey: AccountInfo?]()) { mapping, chainAsset in
            guard let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return
            }
            let key = chainAsset.uniqueKey(accountId: accountId)

            mapping[key] = chainAsset.asset.accountInfo
        }

        DispatchQueue.main.async {
            self.presenter?.didRecieceAccountInfos(accountInfos)
        }
    }

    private func replaceAccountInfoSubscriptionAdapter() {
        if let account = SelectedWalletSettings.shared.value {
            accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: account
            )
        }
    }

    private func subscribeToFiats() {
        fiatInfoProvider = nil

        guard let fiatUrl = ApplicationConfig.shared.fiatsURL else { return }
        fiatInfoProvider = jsonDataProviderFactory.getJson(for: fiatUrl)

        let updateClosure: ([DataProviderChange<[Currency]>]) -> Void = { [weak self] changes in
            if let result = changes.reduceToLastChange() {
                self?.presenter?.didReceiveSupportedCurrencys(.success(result))
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter?.didReceiveSupportedCurrencys(.failure(error))
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: true,
            waitsInProgressSyncOnAdd: false
        )

        fiatInfoProvider?.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func save(_ currency: Currency) {
        let updatedAccount = selectedMetaAccount.replacingCurrency(currency)

        let operation = metaAccountRepository.saveOperation {
            [updatedAccount]
        } _: {
            []
        }

        operation.completionBlock = { [weak self] in
            SelectedWalletSettings.shared.performSave(value: updatedAccount) { result in
                switch result {
                case let .success(account):
                    self?.eventCenter.notify(with: MetaAccountModelChangedEvent(account: account))
                case .failure:
                    break
                }
            }
        }

        operationQueue.addOperation(operation)
    }
}

extension ChainAccountBalanceListInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrices(result: Result<[PriceData], Error>) {
        switch result {
        case let .success(prices):
            updatePrices(with: prices)
        case let .failure(error):
            presenter?.didReceivePricesData(result: .failure(error))
        }
        presenter?.didReceivePricesData(result: result)
    }

    private func updatePrices(with priceData: [PriceData]) {
        let updatedAssets = priceData.compactMap { priceData -> AssetModel? in
            let chainAsset = chains?
                .compactMap { Array($0.assets) }
                .reduce([], +)
                .first(where: { $0?.asset.priceId == priceData.priceId })

            guard let asset = chainAsset?.asset else {
                return nil
            }
            return asset.replacingPrice(
                Decimal(string: priceData.price),
                fiatDayChange: priceData.fiatDayChange
            )
        }

        let saveOperation = assetRepository.saveOperation {
            updatedAssets
        } _: {
            []
        }

        operationQueue.addOperation(saveOperation)
    }
}

extension ChainAccountBalanceListInteractor: ChainAccountBalanceListInteractorInputProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)
        fetchChainsAndSubscribeBalance()
        presenter?.didReceiveSelectedAccount(selectedMetaAccount)
        presenter?.didRecieveSelectedCurrency(currency)
    }

    func refresh() {
        guard let chains = chains else {
            return
        }

        subscribeToPrice(for: chains)
    }

    func didReceive(currency: Currency) {
        save(currency)
    }

    func fetchFiats() {
        subscribeToFiats()
    }
}

extension ChainAccountBalanceListInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset: ChainAsset) {
        presenter?.didReceiveAccountInfo(result: result, for: chainAsset)

        guard case let .success(accountInfo) = result else {
            return
        }

        updateAccountInfo(accountInfo, chainAsset: chainAsset)
    }

    private func updateAccountInfo(_ accountInfo: AccountInfo?, chainAsset: ChainAsset) {
        let chainAsset = chains?
            .compactMap { Array($0.assets) }
            .reduce([], +)
            .first(where: { $0?.asset.id == chainAsset.asset.id })

        guard let asset = chainAsset?.asset else {
            return
        }
        let assetWithReplacedAccountInfo = asset.replacingAccountInfo(accountInfo)

        let saveOperation = assetRepository.saveOperation {
            [assetWithReplacedAccountInfo]
        } _: {
            []
        }

        operationQueue.addOperation(saveOperation)
    }
}

extension ChainAccountBalanceListInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        replaceAccountInfoSubscriptionAdapter()
        fetchChainsAndSubscribeBalance()
    }

    func processChainsUpdated(event _: ChainsUpdatedEvent) {
        fetchChainsAndSubscribeBalance()
    }

    func processSelectedConnectionChanged(event _: SelectedConnectionChanged) {
        refresh()
    }

    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        if selectedMetaAccount.metaId == event.account.metaId {
            selectedMetaAccount = event.account
            currency = event.account.selectedCurrency
            presenter?.didReceiveSelectedAccount(selectedMetaAccount)
            presenter?.didRecieveSelectedCurrency(currency)
            pricesProvider = nil
            fetchChainsAndSubscribeBalance()
        }
    }

    func processWalletNameChanged(event: WalletNameChanged) {
        presenter?.didReceiveSelectedAccount(event.wallet)
    }
}

extension ChainAccountBalanceListInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        refresh()
    }
}

extension ChainAccountBalanceListInteractor: AnyProviderAutoCleaning {}
