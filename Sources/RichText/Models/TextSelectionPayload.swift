import Foundation

public struct RichTextAttachmentAnchor: Equatable, Sendable {
  public let x: Double
  public let y: Double

  public init(x: Double, y: Double) {
    self.x = min(max(x, 0), 1)
    self.y = min(max(y, 0), 1)
  }
}

public struct WordClickPayload: Equatable, Sendable {
  public let word: String
  public let attachmentAnchor: RichTextAttachmentAnchor?

  public init(word: String, attachmentAnchor: RichTextAttachmentAnchor? = nil) {
    self.word = word
    self.attachmentAnchor = attachmentAnchor
  }
}

public struct TextSelectionPayload: Equatable, Sendable {
  public let selectedText: String
  public let contextText: String
  public let attachmentAnchor: RichTextAttachmentAnchor?

  public init(
    selectedText: String,
    contextText: String,
    attachmentAnchor: RichTextAttachmentAnchor? = nil
  ) {
    self.selectedText = selectedText
    self.contextText = contextText
    self.attachmentAnchor = attachmentAnchor
  }
}

func normalizeTextSelectionPayload(
  selectedText: String,
  contextText: String?,
  anchorX: Double? = nil,
  anchorY: Double? = nil
) -> TextSelectionPayload? {
  let normalizedSelection =
    selectedText
    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    .trimmingCharacters(in: .whitespacesAndNewlines)

  guard !normalizedSelection.isEmpty else {
    return nil
  }

  let normalizedContext = (contextText ?? "")
    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    .trimmingCharacters(in: .whitespacesAndNewlines)

  let attachmentAnchor = normalizeRichTextAttachmentAnchor(x: anchorX, y: anchorY)

  return TextSelectionPayload(
    selectedText: normalizedSelection,
    contextText: normalizedContext.isEmpty ? normalizedSelection : normalizedContext,
    attachmentAnchor: attachmentAnchor
  )
}

func normalizeRichTextAttachmentAnchor(
  x: Double?,
  y: Double?
) -> RichTextAttachmentAnchor? {
  guard let x,
    let y,
    x.isFinite,
    y.isFinite
  else {
    return nil
  }

  return RichTextAttachmentAnchor(x: x, y: y)
}
