//  ReaderBackdrop.swift
//  What is behind the reader's floating controls, and which ink that asks for.
//
//  The PDF lane's chrome floats over two grounds at once — the white page and
//  the black stage below it — and one fixed ink cannot serve both: white ink
//  on glass over white paper is invisible, and the row that floats highest
//  over the page is exactly the one the scrim darkens least. So each control
//  asks what is actually behind it — page or stage, light or dark — and its
//  ink follows the answer. The EPUB lane resolves the same question from the
//  reading theme (`ReaderTheme.ink`); a PDF's pages carry their own colour,
//  so this lane resolves it from the pixels.

import CoreGraphics
import SwiftUI

/// The ground a floating control sits on, and so the ink that reads on it.
enum ReaderGround: Equatable {
    /// The dark stage between and below pages — the reader's default ground.
    /// Also any page whose own pixels read dark: a cover, a scan.
    case stage
    /// Light paper under the control; ink takes the light theme's ink.
    case page
}

extension ReaderGround {
    /// The ink a control on this ground draws in. The stage keeps the lane's
    /// long-standing white; the page takes the same token the EPUB lane's
    /// `barInk` uses for chrome over light paper.
    var ink: Color {
        switch self {
        case .stage: .white
        case .page: ReaderTheme.ink("light")
        }
    }
}

/// The ground decision, and the brightness read it turns on.
enum ReaderBackdrop {
    /// Fraction of a control's frame the page has to sit under before the
    /// page counts as its ground — a row clipping the page's last few points
    /// is on the stage for reading purposes.
    static let pageCoverageFloor = 0.3

    /// Mean luminance (0…1) at or above which the page under a control reads
    /// as light paper. Generous on purpose: only paper that is clearly white
    /// flips a row to dark ink, and every uncertain answer keeps the stage's
    /// white — the treatment that never disappears entirely.
    static let lightPaperFloor = 0.55

    /// Which ground a control is on.
    ///
    /// - Parameters:
    ///   - control: the control's frame, in the stage view's coordinates.
    ///   - pageFrame: the current page's frame, same coordinates, or `nil`
    ///     when no page is on screen.
    ///   - pageLuminance: reads the mean luminance of the given rect (stage
    ///     coordinates); called only where the page meets the control, so a
    ///     sample is never spent on a control that is wholly over the stage.
    static func ground(
        control: CGRect,
        pageFrame: CGRect?,
        pageLuminance: (CGRect) -> Double?
    ) -> ReaderGround {
        guard let pageFrame, !pageFrame.isEmpty else { return .stage }
        let overlap = control.intersection(pageFrame)
        guard !overlap.isNull, overlap.width > 0, overlap.height > 0 else { return .stage }
        let coverage = (overlap.width * overlap.height) / (control.width * control.height)
        guard coverage >= pageCoverageFloor else { return .stage }
        guard let luminance = pageLuminance(overlap) else { return .stage }
        return luminance >= lightPaperFloor ? .page : .stage
    }

    /// Mean luminance (0…1) of an image's pixels — sRGB-weighted, so green
    /// counts for what the eye gives it. The image is normally a small crop
    /// of the stage, so the read is a colour decision, not a photograph.
    static func meanLuminance(of image: CGImage) -> Double {
        let side = 16
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard image.width > 0, image.height > 0,
              let context = CGContext(
                  data: &pixels,
                  width: side,
                  height: side,
                  bitsPerComponent: 8,
                  bytesPerRow: side * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return 0 }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        var total = 0.0
        for pixel in stride(from: 0, to: pixels.count, by: 4) {
            total += 0.2126 * Double(pixels[pixel]) / 255
                + 0.7152 * Double(pixels[pixel + 1]) / 255
                + 0.0722 * Double(pixels[pixel + 2]) / 255
        }
        return total / Double(side * side)
    }
}
