import UIKit

final class WalletDetailsViewLayout: UIView {
    var walletView: CommonInputView = {
        let view = CommonInputView()
        view.animatedInputField.textField.returnKeyType = .done
        return view
    }()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.refreshControl = UIRefreshControl()
        view.separatorColor = R.color.colorDarkGray()
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.bigOffset, right: 0)

        return view
    }()

    let navigationLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        label.textAlignment = .center
        return label
    }()

    lazy var navigationBar: BaseNavigationBar = {
        let navBar = BaseNavigationBar()
        navBar.set(.present)
        return navBar
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        configureTextField()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(to viewModel: WalletDetailsViewModel) {
        navigationLabel.text = viewModel.navigationTitle
    }
}

private extension WalletDetailsViewLayout {
    func configureTextField() {
        walletView.animatedInputField.textField.returnKeyType = .done
        walletView.animatedInputField.textField.textContentType = .nickname
        walletView.animatedInputField.textField.autocapitalizationType = .none
        walletView.animatedInputField.textField.autocorrectionType = .no
        walletView.animatedInputField.textField.spellCheckingType = .no
    }

    func setupLayout() {
        backgroundColor = R.color.colorBlack()

        addSubview(navigationBar)
        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        navigationBar.setCenterViews([navigationLabel])

        addSubview(walletView)
        walletView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.defaultOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(52)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.equalTo(walletView.snp.bottom).offset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.hugeOffset)
        }
    }
}
