import SwiftUI
import UIKit
import PDFKit

enum WorkoutPDFRenderer {
  @MainActor
  static func renderPDF(_ workout: Workout, athleteName: String?) -> URL? {
    let view = WorkoutPrintView(workout: workout, athleteName: athleteName)
    let renderer = ImageRenderer(content: view)
    renderer.proposedSize = .init(width: 612, height: 792)

    let fileName = "workout-\(workout.id.prefix(8)).pdf"
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

    var pageBox = CGRect(x: 0, y: 0, width: 612, height: 792)
    guard let ctx = CGContext(url as CFURL, mediaBox: &pageBox, nil) else { return nil }

    renderer.render { size, drawing in
      ctx.beginPDFPage(nil)
      ctx.translateBy(x: 0, y: 0)
      drawing(ctx)
      ctx.endPDFPage()
    }
    ctx.closePDF()
    return url
  }
}
