import Foundation

@available(*, deprecated, message: "Use MetaAccountImportMnemonicRequest or ChainAccountImportMnemonicRequest instead")
struct AccountImportMnemonicRequest {
    let mnemonic: String
    let username: String
    let networkType: Chain
    let derivationPath: String
    let cryptoType: CryptoType
}

@available(*, deprecated, message: "Use MetaAccountImportSeedRequest or ChainAccountImportSeedRequest instead")
struct AccountImportSeedRequest {
    let seed: String
    let username: String
    let networkType: Chain
    let derivationPath: String
    let cryptoType: CryptoType
}

@available(*, deprecated, message: "Use MetaAccountImportKeystoreRequest or ChainAccountImportKeystoreRequest instead")
struct AccountImportKeystoreRequest {
    let keystore: String
    let password: String
    let username: String
    let networkType: Chain
    let cryptoType: CryptoType
}

struct MetaAccountImportMnemonicRequest {
    let mnemonic: String
    let username: String
    let derivationPath: String
    let cryptoType: MultiassetCryptoType
}

struct MetaAccountImportSeedRequest {
    let seed: String
    let username: String
    let derivationPath: String
    let cryptoType: MultiassetCryptoType
}

struct MetaAccountImportKeystoreRequest {
    let keystore: String
    let password: String
    let username: String
    let cryptoType: MultiassetCryptoType
}

struct ChainAccountImportMnemonicRequest {
    let mnemonic: String
    let username: String
    let derivationPath: String
    let cryptoType: MultiassetCryptoType
}

struct ChainAccountImportSeedRequest {
    let seed: String
    let username: String
    let derivationPath: String
    let cryptoType: MultiassetCryptoType
}

struct ChainAccountImportKeystoreRequest {
    let keystore: String
    let password: String
    let username: String
    let cryptoType: MultiassetCryptoType
}
