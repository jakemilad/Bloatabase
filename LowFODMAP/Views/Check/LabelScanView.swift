import PhotosUI
import SwiftUI
@preconcurrency import Vision
import VisionKit

struct LabelScanView: View {
    @Environment(FoodStore.self) private var store

    @State private var text = ""
    @State private var report: IngredientAnalyzer.Report?
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showLiveScanner = false
    @State private var isReading = false
    @State private var error: String?
    @FocusState private var editorFocused: Bool

    private static let example = "Ingredients: Wheat flour, sugar, vegetable oil (palm, canola), onion powder, salt, garlic-infused oil, milk solids, inulin, natural flavours, yeast, emulsifier (soy lecithin), spices."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                captureButtons
                editor
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.fodmapAmber)
                }
                if let report {
                    results(report)
                } else {
                    tips
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await readPhoto(item) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                if let image { Task { await recognize(image) } }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showLiveScanner) {
            LiveTextScanner { scanned in
                showLiveScanner = false
                text = scanned
                analyze()
            }
            .ignoresSafeArea()
        }
    }

    private var captureButtons: some View {
        HStack(spacing: 10) {
            Button {
                if LiveTextScanner.isAvailable {
                    showLiveScanner = true
                } else if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showCamera = true
                } else {
                    error = "No camera available on this device — choose a photo or paste the text instead."
                }
            } label: {
                captureLabel("Scan label", symbol: "camera.viewfinder")
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                captureLabel("From photo", symbol: "photo.on.rectangle")
            }
            Button {
                if let pasted = UIPasteboard.general.string, !pasted.isEmpty {
                    text = pasted
                    analyze()
                } else {
                    editorFocused = true
                }
            } label: {
                captureLabel("Paste", symbol: "doc.on.clipboard")
            }
        }
        .buttonStyle(.plain)
    }

    private func captureLabel(_ title: String, symbol: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .light))
                .frame(height: 27)
            Text(title).font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 93)
        .foregroundStyle(AppStyle.pine)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
    }

    private var editor: some View {
        Card(padding: 12) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("…or type the ingredient list here")
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }
                TextEditor(text: $text)
                    .focused($editorFocused)
                    .frame(minHeight: 90, maxHeight: 180)
                    .scrollContentBackground(.hidden)
            }
            .font(.subheadline)
            HStack {
                if isReading {
                    ProgressView().controlSize(.small)
                    Text("Reading label…").font(.caption).foregroundStyle(.secondary)
                } else if text.isEmpty {
                    Button("Try an example") {
                        text = Self.example
                        analyze()
                    }
                    .font(.subheadline)
                } else {
                    Button("Clear", role: .destructive) {
                        text = ""
                        report = nil
                    }
                    .font(.subheadline)
                }
                Spacer()
                Button {
                    editorFocused = false
                    analyze()
                } label: {
                    Label("Check", systemImage: "checkmark.shield.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func results(_ report: IngredientAnalyzer.Report) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VerdictCard(rating: report.overall, title: report.headline,
                        subtitle: report.findings.isEmpty ? nil : "\(report.high.count) high · \(report.moderate.count) to check · \(report.findings.count) ingredients read")

            if !report.groups.isEmpty {
                FlowLayout {
                    ForEach(report.groups) { g in
                        Text("\(g.emoji) \(g.name)")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.fodmapRed.opacity(0.12), in: Capsule())
                    }
                }
            }

            Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(report.findings) { f in
                        findingRow(f)
                        if f.id != report.findings.last?.id { Divider().padding(.leading, 40) }
                    }
                }
            }
            Text("Ingredients are listed by weight — a trigger near the end of the list is present in a smaller amount. Labels can change, so double-check packaging.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func findingRow(_ f: IngredientAnalyzer.Finding) -> some View {
        let content = HStack(alignment: .top, spacing: 12) {
            Group {
                if let r = f.rating {
                    Image(systemName: r.symbol).foregroundStyle(r.color)
                } else {
                    Image(systemName: "circle.dashed").foregroundStyle(.secondary)
                }
            }
            .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(f.ingredient.capitalizedFirst).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                Text(f.reason).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if f.matchedFoodID != nil {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)

        if let id = f.matchedFoodID, let food = store.food(id) {
            NavigationLink(value: food) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }

    private var tips: some View {
        Card {
            Label("What we look for", systemImage: "eye.fill").font(.headline)
            ForEach([
                ("🧄", "Onion & garlic", "including powders, salts and “natural flavours”"),
                ("🌾", "Wheat, rye & barley", "plus inulin and chicory root fibre"),
                ("🍯", "Honey, agave & fructose", "and fruit juice concentrates"),
                ("🍬", "Sugar alcohols", "sorbitol, mannitol, xylitol, maltitol, isomalt"),
                ("🥛", "Milk solids & lactose", "but lactose-free and butter are fine"),
                ("🫘", "Legumes", "beans, lentils, chickpeas and soy flour"),
            ], id: \.1) { emoji, title, detail in
                HStack(alignment: .top, spacing: 10) {
                    Text(emoji)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title).font(.subheadline.weight(.semibold))
                        Text(detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - OCR

    private func analyze() {
        error = nil
        withAnimation(.spring) {
            report = IngredientAnalyzer(store: store).analyze(text)
        }
    }

    private func readPhoto(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
            error = "Couldn't open that photo."
            return
        }
        await recognize(image)
    }

    @MainActor
    private func recognize(_ image: UIImage) async {
        guard let cg = image.cgImage else { return }
        isReading = true
        defer { isReading = false }
        let lines: [String] = await withCheckedContinuation { cont in
            let request = VNRecognizeTextRequest { req, _ in
                let obs = (req.results as? [VNRecognizedTextObservation]) ?? []
                cont.resume(returning: obs.compactMap { $0.topCandidates(1).first?.string })
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cg, orientation: image.cgOrientation)
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) } catch { cont.resume(returning: []) }
            }
        }
        if lines.isEmpty {
            error = "Couldn't find any text. Try a closer, well-lit photo of the ingredients."
            return
        }
        text = lines.joined(separator: " ")
        analyze()
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

extension UIImage {
    var cgOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        case .upMirrored: .upMirrored
        case .downMirrored: .downMirrored
        case .leftMirrored: .leftMirrored
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}

/// Plain camera capture fallback.
struct CameraPicker: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void
        init(onFinish: @escaping (UIImage?) -> Void) { self.onFinish = onFinish }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onFinish(nil) }
    }
}

/// Live text scanning with VisionKit: point at the label and tap "Use text".
struct LiveTextScanner: View {
    let onScan: (String) -> Void
    @State private var captured = ""
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            DataScannerRepresentable(text: $captured)
            VStack(spacing: 12) {
                Text(captured.isEmpty ? "Point at the ingredient list" : captured)
                    .font(.caption)
                    .lineLimit(4)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                HStack {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Use text") { onScan(captured) }
                        .buttonStyle(.borderedProminent)
                        .disabled(captured.isEmpty)
                }
            }
            .padding(20)
            .padding(.bottom, 20)
        }
    }
}

struct DataScannerRepresentable: UIViewControllerRepresentable {
    @Binding var text: String

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        @Binding var text: String
        init(text: Binding<String>) { _text = text }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            update(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            update(allItems)
        }

        private func update(_ items: [RecognizedItem]) {
            text = items.compactMap { item -> String? in
                if case .text(let t) = item { return t.transcript }
                return nil
            }
            .joined(separator: " ")
        }
    }
}
