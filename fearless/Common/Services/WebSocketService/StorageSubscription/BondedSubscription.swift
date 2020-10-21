import Foundation

final class BondedSubscription: StorageChildSubscribing {
    let storageKey: Data
    let logger: LoggerProtocol
    let stakingSubscription: StakingInfoSubscription

    init(storageKey: Data,
         stakingSubscription: StakingInfoSubscription,
         logger: LoggerProtocol) {
        self.storageKey = storageKey
        self.stakingSubscription = stakingSubscription
        self.logger = logger
    }

    func processUpdate(_ data: Data?, blockHash: Data?) {
        if let controllerId = data {
            logger.debug("Did receive controller \(controllerId.toHex(includePrefix: true))")
        } else {
            logger.debug("No controller account found")
        }

        stakingSubscription.controllerId = data
    }
}
