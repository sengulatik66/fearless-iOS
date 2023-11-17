import UIKit
import SoraFoundation
import RobinHood
import SSFNetwork
import SoraKeystore

final class MainNftContainerAssembly {
    static func configureModule(wallet: MetaAccountModel) -> MainNftContainerModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let nftFetchingService = AlchemyNftFetchingService(
            operationFactory: AlchemyNFTOperationFactory(),
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationQueue()
        )

        let filters = [FilterSet(
            title: R.string.localizable.commonShow(
                preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages
            ),
            items: NftCollectionFilter.defaultFilters()
        )]

        let stateHolder = MainNftContainerStateHolder(filters: filters)

        let interactor = MainNftContainerInteractor(
            nftFetchingService: nftFetchingService,
            logger: Logger.shared,
            wallet: wallet,
            eventCenter: EventCenter.shared,
            stateHolder: stateHolder
        )
        let router = MainNftContainerRouter()

        let presenter = MainNftContainerPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            viewModelFactory: NftListViewModelFactory(),
            wallet: wallet,
            eventCenter: EventCenter.shared,
            userDefaultsStorage: SettingsManager.shared,
            stateHolder: stateHolder
        )

        let view = MainNftContainerViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
