typealias NftDetailsModuleCreationResult = (view: NftDetailsViewInput, input: NftDetailsModuleInput)

protocol NftDetailsViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: NftDetailViewModel)
}

protocol NftDetailsViewOutput: AnyObject {
    func didLoad(view: NftDetailsViewInput)
    func didBackButtonTapped()
    func didTapSendButton()
    func didTapShareButton()
    func didTapCopyOwner()
    func didTapCopyTokenId()
}

protocol NftDetailsInteractorInput: AnyObject {
    func setup(with output: NftDetailsInteractorOutput)
}

protocol NftDetailsInteractorOutput: AnyObject {
    func didReceive(nft: NFT)
}

protocol NftDetailsRouterInput: AnyObject, PushDismissable, ApplicationStatusPresentable, SharingPresentable {
    func openSend(nft: NFT, wallet: MetaAccountModel, from view: ControllerBackedProtocol?)
}

protocol NftDetailsModuleInput: AnyObject {}

protocol NftDetailsModuleOutput: AnyObject {}
