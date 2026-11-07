import UIKit
import Vision

enum TextReader {
    static func lines(from images: [UIImage]) async throws -> [String] {
        var all: [String] = []
        for image in images {
            all += try await lines(from: image)
        }
        return all
    }

    static func lines(from image: UIImage) async throws -> [String] {
        guard let cg = image.cgImage else { return [] }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["de-DE"]
            request.usesLanguageCorrection = false
            let handler = VNImageRequestHandler(cgImage: cg, orientation: orientation)
            try handler.perform([request])
            return group(request.results ?? [])
        }.value
    }

    private struct Piece {
        let text: String
        let box: CGRect
    }

    static func group(_ observations: [VNRecognizedTextObservation]) -> [String] {
        let pieces = observations.compactMap { o -> Piece? in
            guard let t = o.topCandidates(1).first?.string else { return nil }
            let s = t.trimmingCharacters(in: .whitespaces)
            return s.isEmpty ? nil : Piece(text: s, box: o.boundingBox)
        }
        .sorted { $0.box.midY > $1.box.midY }

        var rows: [[Piece]] = []
        for p in pieces {
            if let last = rows.last {
                let mid = last.map { $0.box.midY }.reduce(0, +) / CGFloat(last.count)
                let h = min(p.box.height, last.map { $0.box.height }.min() ?? p.box.height)
                if abs(p.box.midY - mid) < h * 0.6 {
                    rows[rows.count - 1].append(p)
                    continue
                }
            }
            rows.append([p])
        }
        return rows.map { row in
            row.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: "  ")
        }
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
