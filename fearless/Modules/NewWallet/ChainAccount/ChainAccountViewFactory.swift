import Foundation
import SoraFoundation
import FearlessUtils
import RobinHood
import SoraKeystore

struct ChainAccountModule {
    let view: ChainAccountViewProtocol?
    let moduleInput: ChainAccountModuleInput?
}

// swiftlint:disable function_body_length
enum ChainAccountViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        moduleOutput: ChainAccountModuleOutput
    ) -> ChainAccountModule? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let operationManager = OperationManagerFacade.sharedManager

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let eventCenter = EventCenter.shared

        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        var subscriptionContainer: StorageSubscriptionContainer?

        let localStorageIdFactory = LocalStorageKeyFactory()
        if let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress(),
           let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
           let accountStorageKey = try? StorageKeyFactory().accountInfoKeyForId(accountId),
           let localStorageKey = try? localStorageIdFactory.createKey(
               from: accountStorageKey,
               key: chainAsset.chain.chainId
           ) {
            let storageRequestFactory = StorageRequestFactory(
                remoteFactory: StorageKeyFactory(),
                operationManager: OperationManagerFacade.sharedManager
            )

            let contactOperationFactory: WalletContactOperationFactoryProtocol = WalletContactOperationFactory(
                storageFacade: SubstrateDataStorageFacade.shared,
                targetAddress: address
            )

            let transactionSubscription = TransactionSubscription(
                engine: connection,
                address: address,
                chain: chainAsset.chain,
                runtimeService: runtimeService,
                txStorage: AnyDataProviderRepository(txStorage),
                contactOperationFactory: contactOperationFactory,
                storageRequestFactory: storageRequestFactory,
                operationManager: operationManager,
                eventCenter: eventCenter,
                logger: Logger.shared
            )

            let accountInfoSubscription = AccountInfoSubscription(
                transactionSubscription: transactionSubscription,
                remoteStorageKey: accountStorageKey,
                localStorageKey: localStorageKey,
                storage: AnyDataProviderRepository(storage),
                operationManager: OperationManagerFacade.sharedManager,
                logger: Logger.shared,
                eventCenter: EventCenter.shared
            )

            subscriptionContainer = StorageSubscriptionContainer(
                engine: connection,
                children: [accountInfoSubscription],
                logger: Logger.shared
            )
        }

        let existentialDepositService = ExistentialDepositService(
            runtimeCodingService: runtimeService,
            operationManager: operationManager,
            engine: connection
        )

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let accountInfoRepository = substrateRepositoryFactory.createChainStorageItemRepository()

        let accountInfoFetching = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .background
        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            accountInfoFetching: accountInfoFetching,
            operationQueue: operationQueue,
            meta: wallet
        )

        let interactor = ChainAccountInteractor(
            wallet: wallet,
            chainAsset: chainAsset,
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: wallet
            ),
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            storageRequestFactory: storageRequestFactory,
            connection: connection,
            operationManager: operationManager,
            runtimeService: runtimeService,
            eventCenter: eventCenter,
            transactionSubscription: subscriptionContainer,
            repository: AccountRepositoryFactory.createRepository(),
            availableExportOptionsProvider: AvailableExportOptionsProvider(),
            settingsManager: SettingsManager.shared,
            existentialDepositService: existentialDepositService,
            chainAssetFetching: chainAssetFetching
        )

        let wireframe = ChainAccountWireframe()

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()
        let viewModelFactory = ChainAccountViewModelFactory(assetBalanceFormatterFactory: assetBalanceFormatterFactory)

        guard let balanceInfoModule = Self.configureBalanceInfoModule(
            wallet: wallet,
            chainAsset: chainAsset
        )
        else {
            return nil
        }

        let presenter = ChainAccountPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            logger: Logger.shared,
            wallet: wallet,
            moduleOutput: moduleOutput,
            balanceInfoModule: balanceInfoModule.input
        )

        interactor.presenter = presenter

        let view = ChainAccountViewController(
            presenter: presenter,
            balanceInfoViewController: balanceInfoModule.view.controller,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return ChainAccountModule(view: view, moduleInput: presenter)
    }

    private static func configureBalanceInfoModule(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) -> BalanceInfoModuleCreationResult? {
        BalanceInfoAssembly.configureModule(with: .chainAsset(
            metaAccount: wallet,
            chainAsset: chainAsset
        ))
    }
}
