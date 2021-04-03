import UIKit
import SoraUI
import SoraFoundation

protocol NetworkInfoViewDelegate: AnyObject {
    func animateAlongsideWithInfo(view: NetworkInfoView)
}

final class NetworkInfoView: UIView {
    @IBOutlet var backgroundView: TriangularedBlurView!
    @IBOutlet var networkInfoContainer: UIView!
    @IBOutlet var titleControl: ActionTitleControl!
    @IBOutlet var collectionView: UICollectionView!

    @IBOutlet var totalStakedTitleLabel: UILabel!
    @IBOutlet var totalStakedAmountLabel: UILabel!
    @IBOutlet var totalStakedFiatAmountLabel: UILabel!
    @IBOutlet var minimumStakeTitleLabel: UILabel!
    @IBOutlet var minimumStakeAmountLabel: UILabel!
    @IBOutlet var minimumStakeFiatAmountLabel: UILabel!
    @IBOutlet var activeNominatorsTitleLabel: UILabel!
    @IBOutlet var activeNominatorsLabel: UILabel!
    @IBOutlet var lockUpPeriodTitleLabel: UILabel!
    @IBOutlet var lockUpPeriodLabel: UILabel!

    @IBOutlet var contentTop: NSLayoutConstraint!
    @IBOutlet var contentHeight: NSLayoutConstraint!

    weak var delegate: NetworkInfoViewDelegate?

    lazy var expansionAnimator: BlockViewAnimatorProtocol = BlockViewAnimator()

    var expanded: Bool { titleControl.isActivated }

    private var skeletonView: SkrullableView?

    var locale = Locale.current {
        didSet {
            applyLocalization()
            applyTitle()
            applyViewModel()
        }
    }

    private var localizableViewModel: LocalizableResource<NetworkStakingInfoViewModelProtocol>?
    private var chainName: LocalizableResource<String>?

    override func awakeFromNib() {
        super.awakeFromNib()

        titleControl.imageView.isUserInteractionEnabled = false
        titleControl.activate(animated: false)
    }

    func setExpanded(_ value: Bool, animated: Bool) {
        guard value != expanded else {
            return
        }

        if value {
            titleControl.activate(animated: animated)
        } else {
            titleControl.deactivate(animated: animated)
        }

        applyExpansion(animated: animated)
    }

    func bind(viewModel: LocalizableResource<NetworkStakingInfoViewModelProtocol>?) {
        localizableViewModel = viewModel

        if viewModel != nil {
            stopLoadingIfNeeded()

            applyViewModel()
        } else {
            startLoading()
        }
    }

    func bind(chainName: LocalizableResource<String>) {
        self.chainName = chainName

        applyTitle()
    }

    private func applyViewModel() {
        guard let viewModel = localizableViewModel else {
            return
        }

        let localizedViewModel = viewModel.value(for: locale)

        totalStakedAmountLabel.text = localizedViewModel.totalStake?.amount
        totalStakedFiatAmountLabel.text = localizedViewModel.totalStake?.price
        minimumStakeAmountLabel.text = localizedViewModel.minimalStake?.amount
        minimumStakeFiatAmountLabel.text = localizedViewModel.minimalStake?.price
        activeNominatorsLabel.text = localizedViewModel.activeNominators
        lockUpPeriodLabel.text = localizedViewModel.lockUpPeriod
    }

    private func applyTitle() {
        guard let chainName = chainName?.value(for: locale) else {
            return
        }

        titleControl.titleLabel.text = R.string.localizable
            .stakingMainNetworkTitle(chainName, preferredLanguages: locale.rLanguages)
        titleControl.invalidateLayout()
    }

    private func applyLocalization() {
        let languages = locale.rLanguages

        totalStakedTitleLabel.text = R.string.localizable
            .stakingMainTotalStakedTitle(preferredLanguages: languages)
        minimumStakeTitleLabel.text = R.string.localizable
            .stakingMainMinimumStakeTitle(preferredLanguages: languages)
        activeNominatorsTitleLabel.text = R.string.localizable
            .stakingMainActiveNominatorsTitle(preferredLanguages: languages)
        lockUpPeriodTitleLabel.text = R.string.localizable
            .stakingMainLockupPeriodTitle(preferredLanguages: languages)
    }

    private func applyExpansion(animated: Bool) {
        if animated {
            expansionAnimator.animate(block: { [weak self] in
                guard let strongSelf = self else {
                    return
                }

                strongSelf.applyExpansionState()

                let animation = CABasicAnimation()
                animation.toValue = strongSelf.backgroundView.blurMaskView?.shapePath
                strongSelf.backgroundView.blurMaskView?.layer
                    .add(animation, forKey: #keyPath(CAShapeLayer.path))

                strongSelf.delegate?.animateAlongsideWithInfo(view: strongSelf)
            }, completionBlock: nil)
        } else {
            applyExpansionState()
            setNeedsLayout()
        }
    }

    private func applyExpansionState() {
        if expanded {
            contentTop.constant = 0.0
            networkInfoContainer.alpha = 1.0
        } else {
            contentTop.constant = -contentHeight.constant
            networkInfoContainer.alpha = 0.0
        }
    }

    func startLoading() {
        guard skeletonView == nil else {
            return
        }

        totalStakedAmountLabel.alpha = 0.0
        totalStakedFiatAmountLabel.alpha = 0.0
        minimumStakeAmountLabel.alpha = 0.0
        minimumStakeFiatAmountLabel.alpha = 0.0
        activeNominatorsLabel.alpha = 0.0
        lockUpPeriodLabel.alpha = 0.0

        setupSkeleton()
    }

    func stopLoadingIfNeeded() {
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        totalStakedAmountLabel.alpha = 1.0
        totalStakedFiatAmountLabel.alpha = 1.0
        minimumStakeAmountLabel.alpha = 1.0
        minimumStakeFiatAmountLabel.alpha = 1.0
        activeNominatorsLabel.alpha = 1.0
        lockUpPeriodLabel.alpha = 1.0
    }

    private func setupSkeleton() {
        let spaceSize = networkInfoContainer.frame.size

        let skeletonView = Skrull(
            size: networkInfoContainer.frame.size,
            decorations: [],
            skeletons: createSkeletons(for: spaceSize)
        )
        .fillSkeletonStart(R.color.colorSkeletonStart()!)
        .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
        .build()

        skeletonView.frame = CGRect(origin: .zero, size: spaceSize)
        skeletonView.autoresizingMask = []
        networkInfoContainer.insertSubview(skeletonView, at: 0)

        self.skeletonView = skeletonView

        skeletonView.startSkrulling()
    }

    private func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let bigRowSize = CGSize(width: 72.0, height: 12.0)
        let smallRowSize = CGSize(width: 57.0, height: 6.0)
        let topInset: CGFloat = 7.0
        let verticalSpacing: CGFloat = 10.0

        return [
            createSkeletoRow(
                under: totalStakedTitleLabel,
                in: spaceSize,
                offset: CGPoint(x: 0.0, y: topInset),
                size: bigRowSize
            ),

            createSkeletoRow(
                under: totalStakedTitleLabel,
                in: spaceSize,
                offset: CGPoint(x: 0.0, y: topInset + bigRowSize.height + verticalSpacing),
                size: smallRowSize
            ),

            createSkeletoRow(
                under: minimumStakeTitleLabel,
                in: spaceSize,
                offset: CGPoint(x: 0.0, y: topInset),
                size: bigRowSize
            ),

            createSkeletoRow(
                under: minimumStakeTitleLabel,
                in: spaceSize,
                offset: CGPoint(x: 0.0, y: topInset + bigRowSize.height + verticalSpacing),
                size: smallRowSize
            ),

            createSkeletoRow(
                under: activeNominatorsTitleLabel,
                in: spaceSize,
                offset: CGPoint(x: 0.0, y: topInset),
                size: bigRowSize
            ),

            createSkeletoRow(
                under: lockUpPeriodTitleLabel,
                in: spaceSize,
                offset: CGPoint(x: 0.0, y: topInset),
                size: bigRowSize
            )
        ]
    }

    private func createSkeletoRow(
        under targetView: UIView,
        in spaceSize: CGSize,
        offset: CGPoint,
        size: CGSize
    ) -> SingleSkeleton {
        let targetFrame = targetView.convert(targetView.bounds, to: networkInfoContainer)

        let position = CGPoint(
            x: targetFrame.minX + offset.x + size.width / 2.0,
            y: targetFrame.maxY + offset.y + size.height / 2.0
        )

        let mappedSize = CGSize(
            width: spaceSize.skrullMapX(size.width),
            height: spaceSize.skrullMapY(size.height)
        )

        return SingleSkeleton(position: spaceSize.skrullMap(point: position), size: mappedSize).round()
    }

    // MARK: Action

    @IBAction func actionToggleExpansion() {
        applyExpansion(animated: true)
    }
}

extension NetworkInfoView: SkeletonLoadable {
    func didDisappearSkeleton() {
        skeletonView?.stopSkrulling()
    }

    func didAppearSkeleton() {
        skeletonView?.startSkrulling()
    }

    func didUpdateSkeletonLayout() {
        guard let skeletonView = skeletonView else {
            return
        }

        if skeletonView.frame.size != networkInfoContainer.frame.size {
            skeletonView.removeFromSuperview()
            self.skeletonView = nil
            setupSkeleton()
        }
    }
}