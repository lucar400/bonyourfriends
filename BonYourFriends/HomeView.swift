import SwiftUI
import PhotosUI
import VisionKit

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var scanning = false
    @State private var picks: [PhotosPickerItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 24)

            Text("🧾")
                .font(.system(size: 64))
                .frame(width: 104, height: 104)
                .inked(Palette.yellow, radius: 30)
                .rotationEffect(.degrees(-6))
                .padding(.bottom, 28)

            Text("Wer hat\nwas gekauft?")
                .font(.rounded(44, .heavy))
                .foregroundStyle(Palette.ink)
                .lineSpacing(-4)
            Text("Bon scannen, jede Zeile nach rechts für deins, nach links für nicht deins wischen. Fertig ist dein Anteil.")
                .font(.rounded(17, .medium))
                .foregroundStyle(Palette.muted)
                .padding(.top, 12)

            Spacer()

            if let error = model.error {
                Text(error)
                    .font(.rounded(15, .semibold))
                    .foregroundStyle(Palette.ink)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .inked(Palette.salmon, radius: 18, shadow: 3)
                    .padding(.bottom, 18)
            }

            VStack(spacing: 14) {
                if VNDocumentCameraViewController.isSupported {
                    Button {
                        scanning = true
                    } label: {
                        Label("Bon scannen", systemImage: "camera.viewfinder")
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: Palette.yellow))
                }

                PhotosPicker(selection: $picks, maxSelectionCount: 3, matching: .images) {
                    Label("Foto auswählen", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(ChunkyButtonStyle(fill: Palette.peri))

                Button("Beispiel ansehen") {
                    model.loadDemo()
                }
                .font(.rounded(16, .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.top, 4)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(Namer.isAvailable ? Palette.olive : Palette.muted)
                    .frame(width: 8, height: 8)
                Text(Namer.status)
                    .font(.rounded(13, .semibold))
                    .foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .overlay {
            if model.busy { BusyOverlay(text: model.status) }
        }
        .fullScreenCover(isPresented: $scanning) {
            DocumentScanner { images in
                scanning = false
                Task { await model.analyze(images) }
            } onCancel: {
                scanning = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: picks) { _, newValue in
            guard !newValue.isEmpty else { return }
            Task {
                var images: [UIImage] = []
                for p in newValue {
                    if let data = try? await p.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                        images.append(img)
                    }
                }
                picks = []
                await model.analyze(images)
            }
        }
    }
}

struct BusyOverlay: View {
    var text: String
    @State private var spin = false

    var body: some View {
        ZStack {
            Palette.paper.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("🧾")
                    .font(.system(size: 54))
                    .frame(width: 96, height: 96)
                    .inked(Palette.mint, radius: 28)
                    .rotationEffect(.degrees(spin ? 8 : -8))
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: spin)
                Text(text)
                    .font(.rounded(18, .bold))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.opacity)
            }
        }
        .onAppear { spin = true }
    }
}
