import SoraFoundation

protocol UsernameSetupViewProtocol: ControllerBackedProtocol {
    func bindUsername(viewModel: InputViewModelProtocol)
    func bindUniqueChain(viewModel: UniqueChainViewModel)
}

protocol UsernameSetupPresenterProtocol: AnyObject {
    func didLoad(view: UsernameSetupViewProtocol)
    func proceed()
}

protocol UsernameSetupWireframeProtocol: AlertPresentable, NetworkTypeSelectionPresentable {
    func proceed(from view: UsernameSetupViewProtocol?, model: UsernameSetupModel)
}

protocol UsernameSetupViewFactoryProtocol: AnyObject {
    static func createViewForOnboarding(flow: AccountCreateFlow) -> UsernameSetupViewProtocol?
    static func createViewForAdding() -> UsernameSetupViewProtocol?
    static func createViewForSwitch() -> UsernameSetupViewProtocol?
}

extension UsernameSetupViewFactoryProtocol {
    static func createViewForOnboarding() -> UsernameSetupViewProtocol? {
        Self.createViewForOnboarding(flow: .wallet)
    }
}
