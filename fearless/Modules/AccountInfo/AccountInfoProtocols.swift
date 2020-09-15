import SoraFoundation
import IrohaCrypto

protocol AccountInfoViewProtocol: ControllerBackedProtocol {
    func set(usernameViewModel: InputViewModelProtocol)
    func set(address: String)
    func set(networkType: SNAddressType)
}

protocol AccountInfoPresenterProtocol: class {
    func setup()
    func activateClose()
    func activateExport()
    func activateCopyAddress()
    func save(username: String)
}

protocol AccountInfoInteractorInputProtocol: class {
    func setup(accountId: String)
    func save(username: String, accountId: String)
}

protocol AccountInfoInteractorOutputProtocol: class {
    func didReceive(accountItem: ManagedAccountItem)
    func didSave(username: String)
    func didReceive(error: Error)
}

protocol AccountInfoWireframeProtocol: AlertPresentable, ErrorPresentable, ModalAlertPresenting {
    func close(view: AccountInfoViewProtocol?)
    func showExport(for accountId: String, from view: AccountInfoViewProtocol?)
}

protocol AccountInfoViewFactoryProtocol: class {
    static func createView(accountId: String) -> AccountInfoViewProtocol?
}
