import Foundation
import Kingfisher
import SwiftUI
import UIKit

struct ComposeMentionSuggestionsPanel: View {
    let suggestions: [HackersPub.SearchActorsByHandleQuery.Data.SearchActorsByHandle]
    let isLoading: Bool
    let onSelect: (HackersPub.SearchActorsByHandleQuery.Data.SearchActorsByHandle) -> Void

    private var listHeight: CGFloat {
        ComposeMentionPanelPlacement.estimatedHeight(
            suggestionCount: suggestions.count
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading && suggestions.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(
                        NSLocalizedString(
                            "compose.mentions.searching",
                            comment: "Mention search loading status"
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(12)
            }

            if !suggestions.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(suggestions, id: \.id) { actor in
                            Button {
                                onSelect(actor)
                            } label: {
                                ComposeMentionSuggestionRow(actor: actor)
                            }
                            .buttonStyle(.plain)

                            if actor.id != suggestions.last?.id {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                }
                .frame(height: listHeight)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
        .accessibilityElement(children: .contain)
    }
}

private struct ComposeMentionSuggestionRow: View {
    let actor: HackersPub.SearchActorsByHandleQuery.Data.SearchActorsByHandle

    var body: some View {
        HStack(spacing: 10) {
            KFImage(URL(string: actor.avatarUrl))
                .placeholder {
                    Circle()
                        .fill(Color.secondary.opacity(0.15))
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.secondary)
                        }
                }
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                if let name = actor.name, !name.isEmpty {
                    HTMLTextView(html: name, font: .subheadline)
                        .lineLimit(1)
                } else {
                    Text(actor.handle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }

                Text(actor.handle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct ComposeTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    @Binding var caretRect: CGRect
    let textInset: EdgeInsets
    let font: UIFont
    let isEditable: Bool

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.alwaysBounceVertical = true
        textView.adjustsFontForContentSizeCategory = false
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self

        if textView.text != text {
            textView.text = text
        }

        if textView.font != font {
            textView.font = font
        }

        textView.textColor = .label
        textView.textContainerInset = UIEdgeInsets(textInset)
        textView.isEditable = isEditable
        textView.isSelectable = true

        let boundedRange = selectedRange.bounded(to: textView.text.utf16.count)
        if textView.selectedRange != boundedRange {
            textView.selectedRange = boundedRange
        }

        context.coordinator.updateCaretRect(textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ComposeTextEditor

        init(parent: ComposeTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            updateCaretRect(textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selectedRange = textView.selectedRange
            updateCaretRect(textView)
        }

        func updateCaretRect(_ textView: UITextView) {
            let textRange = textView.selectedTextRange
                ?? textView.textRange(
                    from: textView.endOfDocument,
                    to: textView.endOfDocument
                )
            guard let textRange else { return }

            let rect = textView.caretRect(for: textRange.start)
            guard rect.isFinite, rect != parent.caretRect else { return }

            DispatchQueue.main.async { [parent] in
                parent.caretRect = rect
            }
        }
    }
}

private extension CGRect {
    var isFinite: Bool {
        origin.x.isFinite
            && origin.y.isFinite
            && size.width.isFinite
            && size.height.isFinite
    }
}

private extension UIEdgeInsets {
    init(_ edgeInsets: EdgeInsets) {
        self.init(
            top: edgeInsets.top,
            left: edgeInsets.leading,
            bottom: edgeInsets.bottom,
            right: edgeInsets.trailing
        )
    }
}

private extension NSRange {
    func bounded(to upperBound: Int) -> NSRange {
        let location = max(0, min(location, upperBound))
        let length = max(0, min(length, upperBound - location))
        return NSRange(location: location, length: length)
    }
}
