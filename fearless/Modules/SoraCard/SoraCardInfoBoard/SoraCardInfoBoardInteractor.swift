import UIKit
import PayWingsOAuthSDK
import SoraKeystore

struct SoraCardSettingsKey {
    static func settingsKey(for wallet: MetaAccountModel) -> String {
        "sora-card-hidden-status-\(wallet.metaId)"
    }
}

final class SoraCardInfoBoardInteractor {
    // MARK: - Private properties

    private weak var output: SoraCardInfoBoardInteractorOutput?
    private let settings: SettingsManagerProtocol
    private let wallet: MetaAccountModel
    private let service: SCKYCService
    private let storage: SCStorage
    private let eventCenter: EventCenterProtocol
    private let tokenHolder: SCTokenHolderProtocol

    init(
        service: SCKYCService,
        settings: SettingsManagerProtocol,
        wallet: MetaAccountModel,
        storage: SCStorage,
        eventCenter: EventCenterProtocol,
        tokenHolder: SCTokenHolderProtocol
    ) {
        self.service = service
        self.settings = settings
        self.wallet = wallet
        self.storage = storage
        self.eventCenter = eventCenter
        self.tokenHolder = tokenHolder
    }
}

// MARK: - SoraCardInfoBoardInteractorInput

extension SoraCardInfoBoardInteractor: SoraCardInfoBoardInteractorInput {
    func setup(with output: SoraCardInfoBoardInteractorOutput) {
        self.output = output

        let key = SoraCardSettingsKey.settingsKey(for: wallet)
        settings.set(value: false, for: key)
        eventCenter.add(observer: self)
    }

    func hideCard() {
        let key = SoraCardSettingsKey.settingsKey(for: wallet)
        settings.set(value: true, for: key)

        let hidden = settings.bool(for: key) ?? false
        output?.didReceive(hiddenState: hidden)
    }

    func fetchStatus() async {
        let status = await service.userStatus() ?? .notStarted
        switch await service.kycAttempts() {
        case let .failure(error):
            await MainActor.run {
                self.output?.didReceive(error: error)
            }
        case let .success(kycAttempts):
            await MainActor.run {
                self.output?.didReceive(
                    status: status,
                    hasFreeAttempts: kycAttempts.hasFreeAttempts
                )
            }
        }
    }

    func prepareStart() async {
        if await storage.token() != nil {
            let response = await service.kycStatuses()

            switch response {
            case let .success(statuses):
                let statusesToShow = statuses.filter { $0.userStatus != .userCanceled }
                await MainActor.run {
                    self.output?.didReceive(kycStatuses: statusesToShow)
                }
            case let .failure(error):
                await MainActor.run {
                    self.output?.didReceive(error: error)
                }
                tokenHolder.removeToken()
                await MainActor.run {
                    self.output?.restartKYC(data: nil)
                }
            }
        } else {
            await MainActor.run {
                self.output?.restartKYC(data: nil)
            }
        }
    }
}

extension SoraCardInfoBoardInteractor: EventVisitorProtocol {
    func processKYCShouldRestart(data: SCKYCUserDataModel?) {
        Task {
            await MainActor.run { [weak self] in
                self?.output?.restartKYC(data: data)
            }
        }
    }

    func processKYCUserStatusChanged() {
        Task { await fetchStatus() }
    }
}
