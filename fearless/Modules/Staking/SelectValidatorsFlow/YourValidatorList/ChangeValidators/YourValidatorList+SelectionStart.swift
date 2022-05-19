import Foundation

extension YourValidatorList {
    final class SelectionStartWireframe: SelectValidatorsStartWireframe {
        private let state: ExistingBonding

        init(state: ExistingBonding) {
            self.state = state
        }

        override func proceedToCustomList(
            from view: ControllerBackedProtocol?,
            flow: CustomValidatorListFlow,
            chainAsset: ChainAsset,
            wallet: MetaAccountModel
        ) {
            guard let nextView = CustomValidatorListViewFactory.createChangeYourValidatorsView(
                chainAsset: chainAsset,
                wallet: wallet,
                flow: flow,
                with: state
            ) else { return }

            view?.controller.navigationController?.pushViewController(
                nextView.controller,
                animated: true
            )
        }

        override func proceedToRecommendedList(
            from view: SelectValidatorsStartViewProtocol?,
            flow: RecommendedValidatorListFlow,
            wallet: MetaAccountModel,
            chainAsset: ChainAsset
        ) {
            guard let nextView = RecommendedValidatorListViewFactory.createChangeYourValidatorsView(
                flow: flow,
                wallet: wallet,
                chainAsset: chainAsset,
                with: state
            ) else {
                return
            }

            view?.controller.navigationController?.pushViewController(
                nextView.controller,
                animated: true
            )
        }
    }
}
