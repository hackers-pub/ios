import Foundation
import Kingfisher
import SwiftUI

struct HTMLRetryableRemoteImage: View {
    let url: URL?
    let alternativeText: String?
    var downsamplingSize: CGSize?
    var cancelsOnDisappear = false
    var failureBackground = Color.gray.opacity(0.1)
    var failureForeground = Color.primary
    var showsAlternativeTextInFailure = true

    @State private var loadAttempt = HTMLMediaLoadAttempt()
    @State private var shouldRetryWhenVisible = false

    var body: some View {
        ZStack {
            if let url, loadAttempt.state != .failed {
                remoteImage(url: url, attemptID: loadAttempt.id)
            } else {
                failureView
            }
        }
        .onChange(of: url) { _, _ in
            loadAttempt = loadAttempt.retrying()
        }
        .onAppear {
            guard shouldRetryWhenVisible else { return }
            shouldRetryWhenVisible = false
            loadAttempt = loadAttempt.retrying()
        }
        .onDisappear {
            shouldRetryWhenVisible = cancelsOnDisappear && loadAttempt.state == .loading
        }
    }

    @ViewBuilder
    private func remoteImage(url: URL, attemptID: UUID) -> some View {
        if let downsamplingSize {
            configuredImage(url: url, attemptID: attemptID)
                .downsampling(size: downsamplingSize)
                .resizable()
                .scaledToFit()
                .id(attemptID)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityAddTraits(.isImage)
        } else {
            configuredImage(url: url, attemptID: attemptID)
                .resizable()
                .scaledToFit()
                .id(attemptID)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityAddTraits(.isImage)
        }
    }

    private func configuredImage(url: URL, attemptID: UUID) -> KFImage {
        KFImage(url)
            .placeholder {
                ZStack {
                    Color.gray.opacity(0.1)
                    ProgressView()
                }
            }
            .cancelOnDisappear(cancelsOnDisappear)
            .onSuccess { _ in
                receive(.succeeded, for: attemptID)
            }
            .onFailure { error in
                guard !error.isTaskCancelled else { return }
                receive(.failed, for: attemptID)
            }
    }

    private var failureView: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title3)
            Text(NSLocalizedString("error.loadFailed.title", comment: "Load failure title"))
                .font(.footnote)

            if let failureAlternativeText {
                Text(failureAlternativeText)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }

            Button(NSLocalizedString("common.retry", comment: "Retry button")) {
                loadAttempt = loadAttempt.retrying()
            }
            .buttonStyle(.bordered)
        }
        .foregroundStyle(failureForeground)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(failureBackground)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let alternativeText,
              !alternativeText.isEmpty
        else {
            return NSLocalizedString("image.action.alertTitle", comment: "Image accessibility label")
        }

        return alternativeText
    }

    private var failureAlternativeText: String? {
        guard showsAlternativeTextInFailure else { return nil }
        guard let alternativeText, !alternativeText.isEmpty else { return nil }
        return alternativeText
    }

    private func receive(_ event: HTMLMediaLoadEvent, for attemptID: UUID) {
        loadAttempt = loadAttempt.applying(event, from: attemptID)
    }
}
