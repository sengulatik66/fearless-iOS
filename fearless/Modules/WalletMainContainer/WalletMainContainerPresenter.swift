import Foundation
import SoraFoundation
import SSFUtils
import SSFModels

final class WalletMainContainerPresenter {
    // MARK: Private properties

    private weak var balanceInfoModuleInput: BalanceInfoModuleInput?
    private weak var assetListModuleInput: ChainAssetListModuleInput?
    private weak var view: WalletMainContainerViewInput?
    private let router: WalletMainContainerRouterInput
    private let interactor: WalletMainContainerInteractorInput

    private var wallet: MetaAccountModel
    private let viewModelFactory: WalletMainContainerViewModelFactoryProtocol
    private var chainSettings: [ChainSettings]?

    // MARK: - State

    private var selectedChain: ChainModel?
    private var issues: [ChainIssue] = []

    // MARK: - Constructors

    init(
        balanceInfoModuleInput: BalanceInfoModuleInput?,
        assetListModuleInput: ChainAssetListModuleInput?,
        wallet: MetaAccountModel,
        viewModelFactory: WalletMainContainerViewModelFactoryProtocol,
        interactor: WalletMainContainerInteractorInput,
        router: WalletMainContainerRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.balanceInfoModuleInput = balanceInfoModuleInput
        self.assetListModuleInput = assetListModuleInput
        self.wallet = wallet
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.router = router

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(
            selectedChain: selectedChain,
            selectedMetaAccount: wallet,
            chainsIssues: issues,
            locale: selectedLocale,
            chainSettings: chainSettings ?? []
        )

        view?.didReceiveViewModel(viewModel)
    }
}

// MARK: - WalletMainContainerViewOutput

extension WalletMainContainerPresenter: WalletMainContainerViewOutput {
    func addressDidCopied() {
        router.presentStatus(
            with: AddressCopiedEvent(locale: selectedLocale),
            animated: true
        )
    }

    func didLoad(view: WalletMainContainerViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel()
    }

    func didTapOnSwitchWallet() {
        router.showWalletManagment(from: view, moduleOutput: self)
    }

    func didTapOnQR() {
        router.showScanQr(from: view, moduleOutput: self)
    }

    func didTapSearch() {
        router.showSearch(from: view, wallet: wallet)
    }

    func didTapSelectNetwork() {
        router.showSelectNetwork(
            from: view,
            wallet: wallet,
            selectedChainId: selectedChain?.chainId,
            chainModels: nil,
            delegate: self
        )
    }

    func didTapOnBalance() {
        router.showSelectCurrency(
            from: view,
            wallet: wallet
        )
    }

    func didTapIssueButton() {
        router.showIssueNotification(
            from: view,
            issues: issues,
            wallet: wallet
        )
    }
}

// MARK: - WalletMainContainerInteractorOutput

extension WalletMainContainerPresenter: WalletMainContainerInteractorOutput {
    func didReceiveSelectedChain(_ chain: ChainModel?) {
        selectedChain = chain
        provideViewModel()
        guard let chainId = chain?.chainId else {
            assetListModuleInput?.updateChainAssets(using: [], sorts: [])
            return
        }
        assetListModuleInput?.updateChainAssets(using: [.chainId(chainId)], sorts: [])
    }

    func didReceiveError(_ error: Error) {
        router.present(error: error, from: view, locale: selectedLocale)
    }

    func didReceiveAccount(_ account: MetaAccountModel) {
        wallet = account
        provideViewModel()

        balanceInfoModuleInput?.replace(infoType: .wallet(wallet: account))
    }

    func didReceiveChainsIssues(chainsIssues: [ChainIssue]) {
        issues = chainsIssues
        provideViewModel()
    }

    func didReceive(chainSettings: [ChainSettings]) {
        self.chainSettings = chainSettings
        provideViewModel()
    }

    func didReceiveControllerAccountIssue(chainAsset: ChainAsset) {
        let action = SheetAlertPresentableAction(
            title: R.string.localizable.controllerAccountIssueAction(preferredLanguages: selectedLocale.rLanguages)
        ) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.router.showControllerAccountFlow(
                from: strongSelf.view,
                chainAsset: chainAsset,
                wallet: strongSelf.wallet
            )
        }

        router.present(
            message: R.string.localizable.stakingControllerDeprecatedDescription(chainAsset.chain.name),
            title: R.string.localizable.commonImportant(preferredLanguages: selectedLocale.rLanguages),
            closeAction: nil,
            from: view,
            actions: [action]
        )
    }

    func didReceiveStashAccountIssue(address: String) {
        let action = SheetAlertPresentableAction(
            title: R.string.localizable.stashAccountIssueAction(preferredLanguages: selectedLocale.rLanguages)
        ) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.router.showImportWallet(from: strongSelf.view)
        }

        router.present(
            message: R.string.localizable.stashAccountIssueMessage(address),
            title: R.string.localizable.commonImportant(preferredLanguages: selectedLocale.rLanguages),
            closeAction: nil,
            from: view,
            actions: [action]
        )
    }
}

// MARK: - Localizable

extension WalletMainContainerPresenter: Localizable {
    func applyLocalization() {
        provideViewModel()
    }
}

extension WalletMainContainerPresenter: WalletMainContainerModuleInput {}

extension WalletMainContainerPresenter: WalletsManagmentModuleOutput {
    func showAddNewWallet() {
        router.showCreateNewWallet(from: view)
    }

    func showImportWallet() {
        router.showImportWallet(from: view)
    }
}

extension WalletMainContainerPresenter: SelectNetworkDelegate {
    func chainSelection(
        view _: SelectNetworkViewInput,
        didCompleteWith chain: ChainModel?,
        contextTag _: Int?
    ) {
        interactor.saveChainIdForFilter(chain?.chainId)
    }
}

extension WalletMainContainerPresenter: ScanQRModuleOutput {
    func didFinishWith(address: String) {
        router.showSendFlow(
            from: view,
            wallet: wallet,
            address: address
        )
    }
}
