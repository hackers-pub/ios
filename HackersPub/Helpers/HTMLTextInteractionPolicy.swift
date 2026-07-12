import UIKit

@MainActor
enum HTMLTextInteractionPolicy {
    static func allowsSelection(in context: HTMLContentRenderingContext) -> Bool {
        switch context {
        case .feedPreview, .embeddedPreview:
            false
        case .detail, .document, .profileBio:
            true
        }
    }

    static func configure(_ textView: UITextView, allowsSelection: Bool) {
        textView.isEditable = false
        textView.isSelectable = allowsSelection
        textView.isScrollEnabled = false
        textView.alwaysBounceVertical = false
        textView.alwaysBounceHorizontal = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
    }
}
