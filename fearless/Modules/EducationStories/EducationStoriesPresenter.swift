import Foundation
import SoraFoundation
import SoraKeystore

final class EducationStoriesPresenter {
    // MARK: Private properties

    private weak var view: EducationStoriesViewProtocol?
    private let router: EducationStoriesRouterProtocol

    private let storiesFactory: EducationStoriesFactory
    private let userDefaultsStorage: SettingsManagerProtocol

    // MARK: - Constructors

    init(
        userDefaultsStorage: SettingsManagerProtocol,
        storiesFactory: EducationStoriesFactory,
        router: EducationStoriesRouterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.userDefaultsStorage = userDefaultsStorage
        self.storiesFactory = storiesFactory
        self.router = router
        self.localizationManager = localizationManager
    }

    private func loadSlides() {
        let slides = createNewsVersion2Stories()
        let state = EducationStoriesViewState.loaded(slides)
        view?.didReceive(state: state)
    }

    private func createNewsVersion2Stories() -> [EducationSlideView] {
        let slides = storiesFactory.createNewsVersion2Stories(for: selectedLocale)
        return slides
    }
}

// MARK: - EducationStoriesPresenterProtocol

extension EducationStoriesPresenter: EducationStoriesPresenterProtocol {
    func didLoad(view: EducationStoriesViewProtocol) {
        self.view = view

        loadSlides()
    }

    func didCloseStories() {
        userDefaultsStorage.set(
            value: false,
            for: EducationStoriesKeys.isNeedShowNewsVersion2.rawValue
        )
        router.showMain()
    }
}

// MARK: - Localizable

extension EducationStoriesPresenter: Localizable {
    func applyLocalization() {
        loadSlides()
    }
}