import UIKit
import SoraFoundation
import FearlessUtils
import RobinHood

final class CrossChainAssembly {
    static func configureModule(
        with chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) -> CrossChainModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let repositoryFacade = SubstrateDataStorageFacade.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: repositoryFacade
        )

        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            selectedMetaAccount: wallet
        )

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: repositoryFacade
        )
        let accountInfoRepository = substrateRepositoryFactory.createChainStorageItemRepository()
        let accountInfoFetching = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            accountInfoFetching: accountInfoFetching,
            operationQueue: operationQueue,
            meta: wallet
        )

        let interactor = CrossChainInteractor(
            chainAssetFetching: chainAssetFetching,
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory
        )
        let router = CrossChainRouter()

        let iconGenerator = PolkadotIconGenerator()
        let viewModelFactory = CrossChainViewModelFactory(iconGenerator: iconGenerator)
        let presenter = CrossChainPresenter(
            originalChainAsset: chainAsset,
            wallet: wallet,
            viewModelFactory: viewModelFactory,
            logger: Logger.shared,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = CrossChainViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
