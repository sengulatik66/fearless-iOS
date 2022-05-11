import UIKit
import SoraUI

protocol ChainAccountBalanceListViewDelegate: AnyObject {
    func accountButtonDidTap()
}

final class ChainAccountBalanceListViewLayout: UIView {
    enum LayoutConstants {
        static let accountButtonSize: CGFloat = 40
        static let manageAssetsIconSize: CGFloat = 24
        static let warningImageSize: CGFloat = 14
        static let balanceSkeletonSize = CGSize(width: 164.0, height: 16.0)
    }

    private var skeletonView: SkrullableView?

    let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = R.image.backgroundImage()
        return imageView
    }()

    let manageAssetsView = TriangularedBlurView()

    let manageAssetsIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconManageAssets()
        return imageView
    }()

    let manageAssetsLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = .white
        return label
    }()

    let manageAssetsButton = UIButton()

    let ethAccountMissingIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconWarning()
        return imageView
    }()

    let accountNameLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = .white
        return label
    }()

    let totalBalanceLabel: ShimmeredLabel = {
        let label = ShimmeredLabel()
        label.font = .h1Title
        label.textColor = .white
        return label
    }()

    let accountButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(R.image.iconFearlessRounded(), for: .normal)
        return button
    }()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.refreshControl = UIRefreshControl()
        view.separatorStyle = .none
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.bigOffset, right: 0)

        return view
    }()

    weak var delegate: ChainAccountBalanceListViewDelegate?

    var locale = Locale.current {
        didSet {
            applyLocalization()
        }
    }

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public methods

    func bind(to viewModel: ChainAccountBalanceListViewModel) {
        accountNameLabel.text = viewModel.accountName
        totalBalanceLabel.apply(state: viewModel.balance)
        ethAccountMissingIconImageView.isHidden = !viewModel.ethAccountMissed

        viewModel.isColdBoot
            ? startSkeletonAmimating()
            : stopSkeletonAnimating()
    }

    // MARK: - Private methods

    private func applyLocalization() {
        manageAssetsLabel.text = R.string.localizable.walletManageAssets(preferredLanguages: locale.rLanguages)
    }

    private func setupLayout() {
        addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(accountNameLabel)
        accountNameLabel.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        addSubview(totalBalanceLabel)
        totalBalanceLabel.snp.makeConstraints { make in
            make.leading.equalTo(accountNameLabel.snp.leading)
            make.top.equalTo(accountNameLabel.snp.bottom).offset(UIConstants.defaultOffset)
        }

        addSubview(accountButton)
        accountButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.centerY.equalTo(totalBalanceLabel.snp.centerY)
            make.size.equalTo(LayoutConstants.accountButtonSize)
        }

        addSubview(manageAssetsView)
        manageAssetsView.addSubview(manageAssetsLabel)
        manageAssetsView.addSubview(manageAssetsIconImageView)
        manageAssetsView.addSubview(ethAccountMissingIconImageView)
        manageAssetsView.addSubview(manageAssetsButton)

        manageAssetsView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.top.equalTo(totalBalanceLabel.snp.bottom).offset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        manageAssetsLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
        }

        manageAssetsIconImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
            make.size.equalTo(LayoutConstants.manageAssetsIconSize)
            make.leading.equalTo(ethAccountMissingIconImageView.snp.trailing).offset(UIConstants.bigOffset)
        }

        ethAccountMissingIconImageView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.warningImageSize)
            make.centerY.equalToSuperview()
        }

        manageAssetsButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(manageAssetsView.snp.bottom).offset(UIConstants.bigOffset)
            make.bottom.equalToSuperview()
        }
    }

    private func configure() {
        accountButton.addTarget(self, action: #selector(accountButtonHandler), for: .touchUpInside)
    }

    @objc
    private func accountButtonHandler() {
        delegate?.accountButtonDidTap()
    }
}

// MARK: - Skeleton

extension ChainAccountBalanceListViewLayout {
    private func startSkeletonAmimating() {
        guard skeletonView == nil else {
            return
        }

        totalBalanceLabel.alpha = 0
        setupSkeleton()
    }

    private func stopSkeletonAnimating() {
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        totalBalanceLabel.alpha = 1
    }

    private func setupSkeleton() {
        guard frame.size != .zero else { return }
        let spaceSize = frame.size

        let skeletonView = Skrull(
            size: spaceSize,
            decorations: [],
            skeletons: createSkeletons(for: spaceSize)
        )
        .fillSkeletonStart(R.color.colorSkeletonStart()!)
        .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
        .build()

        skeletonView.frame = CGRect(origin: .zero, size: spaceSize)
        skeletonView.autoresizingMask = []
        insertSubview(skeletonView, belowSubview: totalBalanceLabel)

        self.skeletonView = skeletonView

        skeletonView.startSkrulling()
    }

    private func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        [
            SingleSkeleton.createRow(
                inPlaceOf: totalBalanceLabel,
                containerView: self,
                spaceSize: spaceSize,
                size: LayoutConstants.balanceSkeletonSize
            )
        ]
    }
}
