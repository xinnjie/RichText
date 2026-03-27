import CoreGraphics

public enum RichTextLayoutMode: Equatable {
  case fitContent
  case scrollable(viewportHeight: CGFloat)
}
