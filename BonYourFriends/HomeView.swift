import SwiftUI
import PhotosUI
import VisionKit

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var scanning = false
    @State private var picks: [PhotosPickerItem] = []
    @State private var pasting = false
    @State private var mascot = MascotPhysics()
    @State private var appeared = false

    private let space = "home"

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 14) {
                        hero
                        if model.busy {
                            busyCard
                        } else {
                            buttons
                        }
                        if let error = model.error, !model.busy {
                            Text(error)
                                .font(.ui(15, 500))
                                .foregroundStyle(Palette.otherText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .inked(Palette.card, radius: 22, border: 2.5, shadow: 3)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        steps
                        if model.appendMode {
                            Button("Zurück zur Liste") { model.cancelAppend() }
                                .buttonStyle(LinkStyle())
                        } else {
                            Button("Beispielbon ausprobieren") { model.loadDemo() }
                                .buttonStyle(LinkStyle())
                        }
                        aiNote
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                MascotLayer(physics: mascot, space: space)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .coordinateSpace(.named(space))
            .onAppear {
                mascot.bounds = CGRect(
                    x: -geo.safeAreaInsets.leading,
                    y: -geo.safeAreaInsets.top,
                    width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                    height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
                )
                appeared = true
                mascot.startMotion()
            }
            .onChange(of: geo.size) { _, size in
                mascot.bounds = CGRect(x: -geo.safeAreaInsets.leading, y: -geo.safeAreaInsets.top, width: size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing, height: size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
            }
        }
        .animation(.springSoft, value: model.busy)
        .animation(.springSoft, value: model.error)
        .fullScreenCover(isPresented: $scanning) {
            DocumentScanner { images in
                scanning = false
                model.scan(images)
            } onCancel: {
                scanning = false
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $pasting) {
            PasteSheet { text in
                pasting = false
                model.read(text: text)
            }
            .presentationDetents([.medium, .large])
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
                model.scan(images)
            }
        }
        .onDisappear {
            mascot.stop()
            mascot.stopMotion()
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Lab(text: model.appendMode ? "Weiterer Bon für \(model.items.count) Artikel" : "Neuer Bon")
            VStack(alignment: .leading, spacing: -2) {
                Headline(plain: "Foto vom", size: 38)
                Highlight(text: "Kassenzettel", size: 38)
                    .padding(.vertical, 2)
                Headline(plain: "machen", size: 38)
            }
            .padding(.bottom, 6)
            HStack(alignment: .bottom) {
                ZStack(alignment: .topLeading) {
                    Text("Bon rein,\nAnteil raus!")
                        .font(.hand(30))
                        .foregroundStyle(Palette.hand)
                        .lineSpacing(-6)
                    HandArrow()
                        .stroke(Palette.hand, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .frame(width: 60, height: 47)
                        .offset(x: 14, y: 56)
                }
                .rotationEffect(.degrees(-6))
                .padding(.top, 10)
                .frame(maxHeight: .infinity, alignment: .top)
                Spacer()
                Color.clear
                    .frame(width: mascot.size.width, height: mascot.size.height)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(space)) } action: { mascot.home = $0 }
            }
            .frame(minHeight: 118)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .inked(Palette.hero, radius: 28)
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            if VNDocumentCameraViewController.isSupported {
                Button {
                    scanning = true
                } label: {
                    Label("Foto aufnehmen", systemImage: "camera")
                }
                .buttonStyle(InkButtonStyle(kind: .dark, height: 56, fontSize: 17))
            }
            PhotosPicker(selection: $picks, maxSelectionCount: 3, matching: .images) {
                Label("Aus Fotos wählen", systemImage: "photo")
            }
            .buttonStyle(InkButtonStyle(kind: .light, height: 56, fontSize: 17))
            Button {
                pasting = true
            } label: {
                Label("Digitalen Bon einfügen", systemImage: "doc.text")
            }
            .buttonStyle(InkButtonStyle(kind: .light, height: 56, fontSize: 17))
        }
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    private var busyCard: some View {
        HStack(spacing: 14) {
            Group {
                if let img = model.busyImage {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Palette.line
                }
            }
            .frame(width: 56, height: 74)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(model.status)
                    .font(.ui(17, 700))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.opacity)
                Text("Dauert nur ein paar Sekunden, alles passiert auf deinem iPhone.")
                    .font(.ui(13, 500))
                    .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
            Spinner()
            Button("Stopp") { model.cancel() }
                .font(.ui(15, 600))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.screen))
        }
        .padding(12)
        .inked(Palette.card, radius: 22, border: 2.5, shadow: 3)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var steps: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            step("Bon\nfotografieren", Palette.peri, -1.4)
            step("Artikel\nprüfen", Palette.yellow, 1.2)
            step("Karten\nwischen", Palette.mint, -1.4)
            step("Anteil\nteilen", Palette.blush, 1.2)
        }
        .padding(.vertical, 2)
    }

    private func step(_ text: String, _ fill: Color, _ angle: Double) -> some View {
        VStack(alignment: .leading) {
            Text(text)
                .font(.ui(16, 700))
                .foregroundStyle(Palette.ink)
                .lineSpacing(-2)
            Spacer(minLength: 8)
            HStack {
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white))
                    .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .inked(fill, radius: 20, border: 2.5, shadow: 3)
        .rotationEffect(.degrees(angle))
    }

    private var aiNote: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Namer.isAvailable ? Palette.olive : Palette.muted)
                .frame(width: 8, height: 8)
            Text(Namer.status + " · Männchen werfen oder schütteln")
                .font(.ui(12, 600))
                .foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ui(16, 700))
            .underline(true, color: Palette.ink)
            .foregroundStyle(Palette.ink)
            .padding(8)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(configuration.isPressed ? .easeOut(duration: 0.06) : .springHard, value: configuration.isPressed)
    }
}

struct PasteSheet: View {
    var onRead: (String) -> Void
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Lab(text: "Digitaler Bon, zum Beispiel aus der Kaufland- oder REWE-App")
            TextEditor(text: $text)
                .font(.ui(15, 500))
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 160)
                .inked(Palette.hero, radius: 18, border: 2.5, shadow: 0)
            Button("Aus Zwischenablage holen") {
                text = UIPasteboard.general.string ?? text
            }
            .buttonStyle(InkButtonStyle(kind: .light, height: 50, fontSize: 15))
            Button("Auslesen") { onRead(text) }
                .buttonStyle(InkButtonStyle(kind: .dark, height: 50, fontSize: 15))
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.screen)
    }
}
