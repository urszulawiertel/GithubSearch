//
//  AvatarImagePresenter.swift
//  GithubSearch
//
//  Created by Ula on 06/04/2026.
//

import UIKit

enum AvatarImagePresenter {

    static func applyPlaceholder(
        to imageView: UIImageView,
        symbolName: String,
        pointSize: CGFloat,
        weight: UIImage.SymbolWeight
    ) {
        imageView.contentMode = .center
        imageView.image = UIImage(
            systemName: symbolName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        )
    }

    static func applyLoadedImage(_ image: UIImage, to imageView: UIImageView) {
        imageView.contentMode = .scaleAspectFill
        imageView.image = image
    }
}
