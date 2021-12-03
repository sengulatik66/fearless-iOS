import Foundation

struct ChainAccountViewFactory {
    static func createView(chain: ChainModel, asset: AssetModel) -> ChainAccountViewProtocol? {
        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let interactor = ChainAccountInteractor(
            selectedMetaAccount: SelectedWalletSettings.shared.value,
            chain: chain,
            asset: asset,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory
        )
        let wireframe = ChainAccountWireframe()

        let viewModelFactory = ChainAccountViewModelFactory(assetBalanceFormatterFactory: AssetBalanceFormatterFactory())

        let presenter = ChainAccountPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            logger: Logger.shared,
            asset: asset
        )

        let view = ChainAccountViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
