import AppKit
import CoreGraphics

// Draw the app's plate-and-leaf mark at 1024 px for the iOS asset catalog.
let size = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8,
    bytesPerRow: 0, space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [r, g, b, a])!
}

let pine = color(0.06, 0.29, 0.27)
let mist = color(0.86, 0.94, 0.91)
let pale = color(0.73, 0.89, 0.83)

context.setFillColor(pine)
context.fill(CGRect(x: 0, y: 0, width: size, height: size))

// The double ring recalls a dinner plate and the circular verdict motif in the app.
context.setStrokeColor(color(0.53, 0.76, 0.68, 0.48))
context.setLineWidth(11)
context.strokeEllipse(in: CGRect(x: 106, y: 106, width: 812, height: 812))
context.setStrokeColor(mist)
context.setLineWidth(21)
context.strokeEllipse(in: CGRect(x: 175, y: 175, width: 674, height: 674))

// One large botanical leaf, deliberately simple enough to read on the home screen.
let leaf = CGMutablePath()
leaf.move(to: CGPoint(x: 335, y: 323))
leaf.addCurve(to: CGPoint(x: 720, y: 694), control1: CGPoint(x: 328, y: 540), control2: CGPoint(x: 487, y: 716))
leaf.addCurve(to: CGPoint(x: 335, y: 323), control1: CGPoint(x: 695, y: 483), control2: CGPoint(x: 533, y: 333))
leaf.closeSubpath()
context.addPath(leaf)
context.setFillColor(pale)
context.fillPath()

context.setStrokeColor(pine)
context.setLineWidth(19)
context.setLineCap(.round)
context.move(to: CGPoint(x: 355, y: 342))
context.addCurve(to: CGPoint(x: 695, y: 669), control1: CGPoint(x: 483, y: 452), control2: CGPoint(x: 592, y: 572))
context.strokePath()

// Fine veins give the symbol its field-guide character at full size.
context.setLineWidth(9)
context.move(to: CGPoint(x: 503, y: 481))
context.addQuadCurve(to: CGPoint(x: 453, y: 603), control: CGPoint(x: 448, y: 515))
context.move(to: CGPoint(x: 566, y: 541))
context.addQuadCurve(to: CGPoint(x: 668, y: 502), control: CGPoint(x: 624, y: 525))
context.strokePath()

let image = context.makeImage()!
let bitmap = NSBitmapImageRep(cgImage: image)
let data = bitmap.representation(using: .png, properties: [:])!
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
