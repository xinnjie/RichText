import Foundation

public struct RichTextDOMCommand: Equatable, Sendable {
  public let id: String
  public let javaScript: String

  public init(id: String, javaScript: String) {
    self.id = id
    self.javaScript = javaScript
  }
}
