import BigInt

typealias WalletTransferFinishBlock = () -> Void

protocol WalletSendConfirmViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(state: WalletSendConfirmViewState)
    func didReceive(title: String)
}

protocol WalletSendConfirmPresenterProtocol: AnyObject {
    func setup()
    func didTapConfirmButton()
    func didTapBackButton()
}

protocol WalletSendConfirmInteractorInputProtocol: AnyObject {
    func setup()
    func submitExtrinsic(for transferAmount: BigUInt, receiverAddress: String)
    func estimateFee(for amount: BigUInt)
}

protocol WalletSendConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveBlockDuration(result: Result<BlockTime, Error>)
    func didReceiveMinimumBalance(result: Result<BigUInt, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)

    func didTransfer(result: Result<String, Error>)
}

protocol WalletSendConfirmWireframeProtocol: AlertPresentable, ErrorPresentable, BaseErrorPresentable, ModalAlertPresenting {
    func close(view: ControllerBackedProtocol?)
    func finish(view: ControllerBackedProtocol?)
    func complete(
        on view: ControllerBackedProtocol?,
        title: String
    )
}