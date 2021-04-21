import XCTest
@testable import fearless
import SoraKeystore
import IrohaCrypto
import RobinHood
import Cuckoo

class StakingPayoutsConfirmTests: XCTestCase {
    func testSetupAndSendExtrinsic() throws {
        // given

        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()

        let addressType = SNAddressType.kusamaMain
        try AccountCreationHelper.createAccountFromMnemonic(cryptoType: .sr25519,
                                                            keychain: keychain,
                                                            settings: settings)

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(addressType)

        let view = MockStakingPayoutConfirmationViewProtocol()
        let wireframe = MockStakingPayoutConfirmationWireframeProtocol()

        let balanceViewModelFactory = BalanceViewModelFactory(walletPrimitiveFactory: primitiveFactory,
                                                              selectedAddressType: addressType,
                                                              limit: StakingConstants.maxAmount)

        let presenter = StakingPayoutConfirmationPresenter(balanceViewModelFactory: balanceViewModelFactory,
                                                           asset: asset)

        let extrinsicService = ExtrinsicServiceStub.dummy()
        let signer = try DummySigner(cryptoType: .sr25519)
        let balanceProvider = DataProviderStub(models: [WestendStub.accountInfo])
        let priceProvider = SingleValueProviderStub(item: WestendStub.price)

        let interactor = StakingPayoutConfirmationInteractor(extrinsicService: extrinsicService,
                                                             signer: signer,
                                                             balanceProvider: AnyDataProvider(balanceProvider),
                                                             priceProvider: AnySingleValueProvider(priceProvider),
                                                             settings: settings,
                                                             payouts: [])
        
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        // when

        let feeExpectation = XCTestExpectation()

        stub(view) { stub in
            when(stub).didReceive(feeViewModel: any()).then { viewModel in
                if viewModel != nil {
                    feeExpectation.fulfill()
                }
            }

            when(stub).didStartLoading().thenDoNothing()
            when(stub).didStopLoading().thenDoNothing()
        }

        let completionExpectation = XCTestExpectation()

        stub(wireframe) { stub in
            when(stub).complete(from: any()).then { _ in
                completionExpectation.fulfill()
            }
        }

        // when

        presenter.setup()

        // then

        wait(for: [feeExpectation], timeout: Constants.defaultExpectationDuration)

        // when

        presenter.proceed()

        // then

        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)
    }
}