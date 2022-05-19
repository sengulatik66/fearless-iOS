import Foundation

class CustomValidatorListRelaychainViewModelState: CustomValidatorListViewModelState {
    var stateListener: CustomValidatorListModelStateListener?

    func setStateListener(_ stateListener: CustomValidatorListModelStateListener?) {
        self.stateListener = stateListener
    }

    let fullValidatorList: [SelectedValidatorInfo]
    let recommendedValidatorList: [SelectedValidatorInfo]
    let selectedValidatorList: SharedList<SelectedValidatorInfo>
    let maxTargets: Int

    var filteredValidatorList: [SelectedValidatorInfo] = []

    var viewModel: CustomValidatorListViewModel?
    var filter: CustomValidatorListFilter = .recommendedFilter()

    init(
        fullValidatorList: [SelectedValidatorInfo],
        recommendedValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        maxTargets: Int
    ) {
        self.fullValidatorList = fullValidatorList
        self.recommendedValidatorList = recommendedValidatorList
        self.selectedValidatorList = selectedValidatorList
        self.maxTargets = maxTargets

        filteredValidatorList = composeFilteredValidatorList(filter: filter)
    }

    func validatorInfoFlow(validatorIndex: Int) -> ValidatorInfoFlow? {
        .relaychain(validatorInfo: filteredValidatorList[validatorIndex], address: nil)
    }

    func validatorSearchFlow() -> ValidatorSearchFlow? {
        .relaychain(validatorList: fullValidatorList, selectedValidatorList: selectedValidatorList.items)
    }

    func performDeselect() {
        guard var viewModel = viewModel else { return }

        let changedModels: [CustomValidatorCellViewModel] = viewModel.cellViewModels.map {
            var newItem = $0
            newItem.isSelected = false
            return newItem
        }

        let indices = viewModel.cellViewModels
            .enumerated()
            .filter {
                $1.isSelected
            }.map { index, _ in
                index
            }

        selectedValidatorList.set([])

        stateListener?.modelStateDidChanged(viewModelState: self)

        viewModel.cellViewModels = changedModels
        viewModel.selectedValidatorsCount = 0
        self.viewModel = viewModel

        stateListener?.viewModelChanged(viewModel, at: indices)
    }

    func changeValidatorSelection(at index: Int) {
        guard var viewModel = viewModel else { return }

        let changedValidator = filteredValidatorList[index]

        guard !changedValidator.blocked else {
            stateListener?.didReceiveError(error: CustomValidatorListFlowError.validatorBlocked)
            return
        }

        if let selectedIndex = selectedValidatorList.firstIndex(of: changedValidator) {
            selectedValidatorList.remove(at: selectedIndex)
            viewModel.selectedValidatorsCount -= 1
        } else {
            selectedValidatorList.append(changedValidator)
            viewModel.selectedValidatorsCount += 1
        }

        viewModel.cellViewModels[index].isSelected = !viewModel.cellViewModels[index].isSelected
        viewModel.selectedValidatorsCount = selectedValidatorList.count
        self.viewModel = viewModel

        stateListener?.viewModelChanged(viewModel, at: [index])
    }

    func composeFilteredValidatorList(filter: CustomValidatorListFilter) -> [SelectedValidatorInfo] {
        let composer = CustomValidatorListComposer(filter: filter)
        return composer.compose(from: fullValidatorList)
    }
}

extension CustomValidatorListRelaychainViewModelState: CustomValidatorListUserInputHandler {
    func remove(validator: SelectedValidatorInfo) {
        if let displayedIndex = filteredValidatorList.firstIndex(of: validator) {
            changeValidatorSelection(at: displayedIndex)
        } else if let selectedIndex = selectedValidatorList.firstIndex(of: validator) {
            selectedValidatorList.remove(at: selectedIndex)

            stateListener?.modelStateDidChanged(viewModelState: self)
        }
    }

    func validatorSearchDidUpdate(selectedValidatorList: [SelectedValidatorInfo]) {
        self.selectedValidatorList.set(selectedValidatorList)

        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func fillWithRecommended() {
        let recommendedToFill = recommendedValidatorList
            .filter { !selectedValidatorList.contains($0) }
            .prefix(maxTargets - selectedValidatorList.count)

        guard !recommendedToFill.isEmpty else { return }

        selectedValidatorList.append(contentsOf: recommendedToFill)

        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func updateViewModel(_ viewModel: CustomValidatorListViewModel) {
        self.viewModel = viewModel
    }

    func updateFilter(_ filter: CustomValidatorListFilter) {
        self.filter = filter

        filteredValidatorList = composeFilteredValidatorList(filter: filter)
    }
}
