import Foundation

public struct TextSelectionPayload: Equatable, Sendable {
  public let selectedText: String
  public let contextText: String

  public init(selectedText: String, contextText: String) {
    self.selectedText = selectedText
    self.contextText = contextText
  }
}

func normalizeTextSelectionPayload(
  selectedText: String,
  contextText: String?
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

  return TextSelectionPayload(
    selectedText: normalizedSelection,
    contextText: normalizedContext.isEmpty ? normalizedSelection : normalizedContext
  )
}
