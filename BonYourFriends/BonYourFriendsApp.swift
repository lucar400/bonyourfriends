import SwiftUI

@main
struct BonYourFriendsApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.light)
                .tint(Palette.ink)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Palette.paper.ignoresSafeArea()
            switch model.screen {
            case .home:
                HomeView().transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .review:
                ReviewView().transition(.move(edge: .trailing).combined(with: .opacity))
            case .swipe:
                SwipeView().transition(.move(edge: .trailing).combined(with: .opacity))
            case .result:
                ResultView().transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
