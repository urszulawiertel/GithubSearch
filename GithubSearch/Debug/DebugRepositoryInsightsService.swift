//
//  DebugRepositoryInsightsService.swift
//  GithubSearch
//

#if DEBUG
import Foundation
import RxSwift

final class DebugRepositoryInsightsService: RepositoryInsightsServicing {
    func generateInsights(for context: RepositoryInsightsContext) -> Single<RepositoryInsights> {
        guard context.hasSufficientData else {
            return .error(RepositoryInsightsServiceError.insufficientData)
        }

        let language = context.primaryLanguage ?? L10n.RepositoryInsights.unknownLanguage
        let releaseStep = context.latestRelease.map {
            L10n.RepositoryInsights.debugReleaseStep($0.tagName)
        } ?? L10n.RepositoryInsights.debugDocumentationStep

        let insights = RepositoryInsights(
            overview: L10n.RepositoryInsights.debugOverview(context.fullName, language),
            usefulFor: [
                L10n.RepositoryInsights.debugUsefulForOne,
                L10n.RepositoryInsights.debugUsefulForTwo
            ],
            nextSteps: [
                L10n.RepositoryInsights.debugCodeStep(language),
                L10n.RepositoryInsights.debugRunStep,
                releaseStep
            ],
            questionsToExplore: [
                L10n.RepositoryInsights.debugQuestionOne,
                L10n.RepositoryInsights.debugQuestionTwo
            ]
        )

        return .just(insights)
            .delay(.milliseconds(450), scheduler: MainScheduler.instance)
    }
}
#endif
