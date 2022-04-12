import UIKit
import SoraUI
import SoraFoundation

final class WalletDetailsViewController: UIViewController, ViewHolder {
    enum Constants {
        static let cellHeight: CGFloat = 48
    }

    typealias RootViewType = WalletDetailsViewLayout

    let output: WalletDetailsViewOutputProtocol
    private var chainViewModels: [WalletDetailsCellViewModel]?
    private var inputViewModel: InputViewModelProtocol?

    private var state: WalletDetailsViewState?

    init(output: WalletDetailsViewOutputProtocol) {
        self.output = output
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = WalletDetailsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()

        output.didLoad(ui: self)
    }

    override func viewWillDisappear(_: Bool) {
        output.willDisappear()
        super.viewWillDisappear(true)
    }

    @objc private func closeButtonClicked() {
        output.didTapCloseButton()
    }

    @objc private func exportButtonClicked() {
        output.didTapExportButton()
    }

    private func applyState() {
        guard let state = state else {
            return
        }

        switch state {
        case let .normal(viewModel):
            rootView.tableView.reloadData()
            rootView.bind(to: viewModel)
        case let .export(viewModel):
            rootView.bind(to: viewModel)
            rootView.tableView.reloadData()
        }
    }
}

extension WalletDetailsViewController: WalletDetailsViewProtocol {
    func didReceive(state: WalletDetailsViewState) {
        self.state = state
        applyState()
    }

    func setInput(viewModel: InputViewModelProtocol) {
        inputViewModel = viewModel
        rootView.walletView.animatedInputField.title = viewModel.title
        rootView.walletView.animatedInputField.text = viewModel.inputHandler.value
    }
}

extension WalletDetailsViewController: AnimatedTextFieldDelegate {
    func animatedTextField(
        _ textField: AnimatedTextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let viewModel = inputViewModel else {
            return true
        }

        let shouldApply = viewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != viewModel.inputHandler.value {
            textField.text = viewModel.inputHandler.value
        }

        return shouldApply
    }

    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool {
        textField.resignFirstResponder()

        return false
    }
}

private extension WalletDetailsViewController {
    func configure() {
        rootView.walletView.animatedInputField.delegate = self

        rootView.tableView.registerClassForCell(WalletDetailsTableCell.self)

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self

        rootView.navigationBar.backButton.addTarget(
            self,
            action: #selector(closeButtonClicked),
            for: .touchUpInside
        )

        rootView.exportButton.addTarget(
            self,
            action: #selector(exportButtonClicked),
            for: .touchUpInside
        )
    }
}

extension WalletDetailsViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        switch state {
        case let .normal(viewModel):
            return viewModel.sections.count
        case let .export(viewModel):
            return viewModel.sections.count
        case .none:
            return 0
        }
    }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch state {
        case let .normal(viewModel):
            return viewModel.sections[section].title
        case let .export(viewModel):
            return viewModel.sections[section].title
        case .none:
            return nil
        }
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch state {
        case let .normal(viewModel):
            return viewModel.sections[section].viewModels.count
        case let .export(viewModel):
            return viewModel.sections[section].viewModels.count
        case .none:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithType(WalletDetailsTableCell.self) else {
            return UITableViewCell()
        }

        switch state {
        case let .normal(viewModel):
            let cellModel = viewModel.sections[indexPath.section].viewModels[indexPath.row]
            cell.bind(to: cellModel)
            cell.delegate = self
            return cell
        case let .export(viewModel):
            let cellModel = viewModel.sections[indexPath.section].viewModels[indexPath.row]
            cell.bind(to: cellModel)
            cell.delegate = self
            return cell
        case .none:
            return UITableViewCell()
        }
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        Constants.cellHeight
    }
}

extension WalletDetailsViewController: UITableViewDelegate {
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch state {
        case let .normal(viewModel):
            UIPasteboard.general.string = viewModel.sections[indexPath.section].viewModels[indexPath.row].address
        case let .export(viewModel):
            UIPasteboard.general.string = viewModel.sections[indexPath.section].viewModels[indexPath.row].address
        case .none:
            break
        }

        if let chain = chainViewModels?[indexPath.row], let address = chain.address {
            UIPasteboard.general.string = address
        }
    }
}

extension WalletDetailsViewController: WalletDetailsTableCellDelegate {
    func didTapActions(_ cell: WalletDetailsTableCell) {
        guard let indexPath = rootView.tableView.indexPath(for: cell) else {
            return
        }

        switch state {
        case let .normal(viewModel):
            let chainAccount = viewModel.sections[indexPath.section].viewModels[indexPath.row].chainAccount
            output.showActions(for: chainAccount)
        default:
            break
        }
    }
}

extension WalletDetailsViewController: HiddableBarWhenPushed {}
