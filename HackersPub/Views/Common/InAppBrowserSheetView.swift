import SafariView
import SwiftUI

struct InAppBrowserSheetView: View {
    let url: URL

    var body: some View {
        SafariView(url: url)
            .ignoresSafeArea()
    }
}
