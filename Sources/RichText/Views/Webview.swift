//
//  WebView.swift
//
//
//  Created by 이웅재(NuPlay) on 2021/07/26.
//  https://github.com/NuPlay/RichText

import SafariServices
import SwiftUI
import WebKit
import os.log

/// Logger for WebView performance monitoring
private let webViewLogger = Logger(subsystem: "com.nuplay.richtext", category: "WebView")

struct WebView {
  @Environment(\.multilineTextAlignment) var alignment
  @Binding var dynamicHeight: CGFloat

  let html: String
  let conf: Configuration
  let width: CGFloat

  init(width: CGFloat, dynamicHeight: Binding<CGFloat>, html: String, configuration: Configuration)
  {
    self._dynamicHeight = dynamicHeight

    self.html = html
    self.conf = configuration
    self.width = width
  }
}

#if canImport(UIKit)
  import UIKit

  private final class SelectableWKWebView: WKWebView {
    var selectionPayload: TextSelectionPayload?
    var onDefineSelection: ((TextSelectionPayload) -> Void)?

    override var canBecomeFirstResponder: Bool {
      true
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
      if action == #selector(defineSelection(_:)) {
        return selectionPayload != nil
      }

      return super.canPerformAction(action, withSender: sender)
    }

    override func buildMenu(with builder: any UIMenuBuilder) {
      super.buildMenu(with: builder)

      guard selectionPayload != nil else { return }

      let defineCommand = UICommand(title: "Define", action: #selector(defineSelection(_:)))
      let defineMenu = UIMenu(title: "", options: .displayInline, children: [defineCommand])
      builder.insertChild(defineMenu, atStartOfMenu: .lookup)
    }

    @objc
    private func defineSelection(_ sender: Any?) {
      _ = sender
      guard let selectionPayload else { return }
      onDefineSelection?(selectionPayload)
    }
  }

  extension WebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
      let configuration = WKWebViewConfiguration()
      configuration.userContentController.add(
        context.coordinator,
        name: RichTextConstants.heightNotificationHandler
      )
      configuration.userContentController.add(
        context.coordinator,
        name: RichTextConstants.mediaClickHandler
      )
      if conf.wordClickHandler != nil {
        let wordClickScript = WKUserScript(
          source: RichTextConstants.wordClickScript,
          injectionTime: .atDocumentEnd,
          forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(wordClickScript)
        configuration.userContentController.add(
          context.coordinator,
          name: RichTextConstants.wordClickHandler
        )
      }
      if conf.textSelectionHandler != nil {
        let textSelectionScript = WKUserScript(
          source: RichTextConstants.textSelectionScript,
          injectionTime: .atDocumentEnd,
          forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(textSelectionScript)
        configuration.userContentController.add(
          context.coordinator,
          name: RichTextConstants.textSelectionHandler
        )
      }
      for (scheme, handler) in conf.schemeHandlers {
        configuration.setURLSchemeHandler(handler, forURLScheme: scheme)
      }
      let webview = SelectableWKWebView(frame: .zero, configuration: configuration)
      webview.onDefineSelection = conf.textSelectionHandler

      // Configure scrolling behavior
      webview.scrollView.bounces = false
      webview.scrollView.isScrollEnabled = false

      // Set delegates
      webview.navigationDelegate = context.coordinator

      // Configure appearance
      webview.isOpaque = false
      webview.backgroundColor = UIColor.clear
      webview.scrollView.backgroundColor = UIColor.clear

      // Load HTML content
      loadHTML(in: webview)

      return webview
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
      loadHTML(in: uiView)
      if let selectableWebView = uiView as? SelectableWKWebView {
        selectableWebView.onDefineSelection = conf.textSelectionHandler
      }

      // Update frame directly without timer to avoid state modification during view update
      uiView.frame.size = .init(width: self.width, height: self.dynamicHeight)
    }

    func makeCoordinator() -> Coordinator {
      Coordinator(self)
    }
  }
#else
  import AppKit
  private class ScrollAdjustedWKWebView: WKWebView {
    override public func scrollWheel(with event: NSEvent) {
      nextResponder?.scrollWheel(with: event)
    }
  }

  private final class SelectableWKWebView: ScrollAdjustedWKWebView, NSMenuItemValidation {
    var selectionPayload: TextSelectionPayload?
    var onDefineSelection: ((TextSelectionPayload) -> Void)?

    override func menu(for event: NSEvent) -> NSMenu? {
      let baseMenu = super.menu(for: event) ?? NSMenu()
      guard selectionPayload != nil else { return baseMenu }

      let menu = baseMenu.copy() as? NSMenu ?? NSMenu()
      let defineItem = NSMenuItem(
        title: "Define", action: #selector(defineSelection(_:)), keyEquivalent: "")
      defineItem.target = self
      menu.insertItem(defineItem, at: 0)
      menu.insertItem(.separator(), at: 1)
      return menu
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
      if menuItem.action == #selector(defineSelection(_:)) {
        return selectionPayload != nil
      }

      return true
    }

    @objc
    private func defineSelection(_ sender: Any?) {
      _ = sender
      guard let selectionPayload else { return }
      onDefineSelection?(selectionPayload)
    }
  }

  extension WebView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
      let configuration = WKWebViewConfiguration()
      configuration.userContentController.add(
        context.coordinator,
        name: RichTextConstants.heightNotificationHandler
      )
      configuration.userContentController.add(
        context.coordinator,
        name: RichTextConstants.mediaClickHandler
      )
      if conf.wordClickHandler != nil {
        let wordClickScript = WKUserScript(
          source: RichTextConstants.wordClickScript,
          injectionTime: .atDocumentEnd,
          forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(wordClickScript)
        configuration.userContentController.add(
          context.coordinator,
          name: RichTextConstants.wordClickHandler
        )
      }
      if conf.textSelectionHandler != nil {
        let textSelectionScript = WKUserScript(
          source: RichTextConstants.textSelectionScript,
          injectionTime: .atDocumentEnd,
          forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(textSelectionScript)
        configuration.userContentController.add(
          context.coordinator,
          name: RichTextConstants.textSelectionHandler
        )
      }
      for (scheme, handler) in conf.schemeHandlers {
        configuration.setURLSchemeHandler(handler, forURLScheme: scheme)
      }
      let webview = SelectableWKWebView(frame: .zero, configuration: configuration)
      webview.onDefineSelection = conf.textSelectionHandler

      // Set delegate
      webview.navigationDelegate = context.coordinator

      // Configure appearance
      webview.setValue(false, forKey: "drawsBackground")

      // Load HTML content
      loadHTML(in: webview)

      return webview
    }

    func updateNSView(_ nsView: WKWebView, context _: Context) {
      loadHTML(in: nsView)
      if let selectableWebView = nsView as? SelectableWKWebView {
        selectableWebView.onDefineSelection = conf.textSelectionHandler
      }
    }

    func makeCoordinator() -> Coordinator {
      Coordinator(self)
    }
  }
#endif

extension WebView {
  class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    var parent: WebView

    init(_ parent: WebView) {
      self.parent = parent
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      handleNavigationError(error)
    }

    func webView(
      _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
      withError error: Error
    ) {
      handleNavigationError(error)
    }

    private func handleNavigationError(_ error: Error) {
      webViewLogger.error("Navigation error: \(error.localizedDescription)")
      Task { @MainActor in
        self.parent.conf.errorHandler?(
          .htmlLoadingFailed("\(error.localizedDescription): \(self.parent.html.prefix(100))"))
      }
    }

    func userContentController(
      _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
      Task { @MainActor in
        await handleScriptMessage(message)
      }
    }

    @MainActor
    private func handleScriptMessage(_ message: WKScriptMessage) async {
      switch message.name {
      case RichTextConstants.heightNotificationHandler:
        await handleHeightUpdate(message.body)

      case RichTextConstants.mediaClickHandler:
        await handleMediaClick(message.body)

      case RichTextConstants.wordClickHandler:
        await handleWordClick(message.body)
      case RichTextConstants.textSelectionHandler:
        await handleTextSelection(message.body, webView: message.webView)

      default:
        webViewLogger.warning("Unknown script message: \(message.name)")
      }
    }

    @MainActor
    private func handleHeightUpdate(_ body: Any) async {
      guard let height = body as? NSNumber else {
        webViewLogger.error("Invalid height value received")
        return
      }

      let cgFloatHeight = CGFloat(height.doubleValue)

      // Only update if height actually changed to avoid unnecessary animations
      guard cgFloatHeight != self.parent.dynamicHeight else { return }

      // Defer the state update to avoid modifying state during view update
      DispatchQueue.main.async {
        withAnimation(self.parent.conf.transition) {
          self.parent.dynamicHeight = cgFloatHeight
        }
      }

      webViewLogger.debug("Height updated to: \(cgFloatHeight)")
    }

    @MainActor
    private func handleMediaClick(_ body: Any) async {
      guard let messageBody = body as? [String: Any],
        let type = messageBody["type"] as? String,
        let src = messageBody["src"] as? String
      else {
        self.parent.conf.errorHandler?(.mediaHandlingFailed("Invalid media message"))
        return
      }

      switch type {
      case "image":
        self.parent.conf.mediaClickHandler?(.image(src: src))
      case "video":
        self.parent.conf.mediaClickHandler?(.video(src: src))
      default:
        self.parent.conf.errorHandler?(.mediaHandlingFailed("Unknown media type: \(type)"))
      }
    }

    @MainActor
    private func handleWordClick(_ body: Any) async {
      guard let word = body as? String else {
        webViewLogger.warning("Invalid word tap payload")
        return
      }

      let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
      guard trimmedWord.count > 1 else { return }

      self.parent.conf.wordClickHandler?(trimmedWord)
    }

    @MainActor
    private func handleTextSelection(_ body: Any, webView: WKWebView?) async {
      guard let webView = webView as? SelectableWKWebView else { return }
      webView.selectionPayload = textSelectionPayload(from: body)
    }

    private func textSelectionPayload(from body: Any) -> TextSelectionPayload? {
      guard let messageBody = body as? [String: Any] else {
        webViewLogger.warning("Invalid text selection payload")
        return nil
      }

      guard let selectedText = messageBody["selectedText"] as? String else {
        return nil
      }

      let contextText = messageBody["contextText"] as? String
      return normalizeTextSelectionPayload(
        selectedText: selectedText,
        contextText: contextText
      )
    }
    func webView(
      _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
      guard navigationAction.navigationType == WKNavigationType.linkActivated,
        var url = navigationAction.request.url
      else {
        decisionHandler(WKNavigationActionPolicy.allow)
        return
      }

      if case .custom(let action) = parent.conf.linkOpenType {
        action(url)
      } else {
        if url.scheme == nil {
          guard let httpsURL = URL(string: "https://\(url.absoluteString)") else {
            decisionHandler(WKNavigationActionPolicy.cancel)
            return
          }
          url = httpsURL
        }

        switch url.scheme {
        case RichTextConstants.mailtoScheme, RichTextConstants.telScheme:
          #if canImport(UIKit)
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
          #else
            NSWorkspace.shared.open(url)
          #endif
        case RichTextConstants.httpScheme, RichTextConstants.httpsScheme:
          switch parent.conf.linkOpenType {
          #if canImport(UIKit)
            case .SFSafariView(let conf, let isReaderActivated, let isAnimated):
              if let reader = isReaderActivated {
                conf.entersReaderIfAvailable = reader
              }
              let root = UIApplication.shared.windows.first?.rootViewController
              root?.present(
                SFSafariViewController(url: url, configuration: conf), animated: isAnimated,
                completion: nil)
          #endif
          case .Safari:
            #if canImport(UIKit)
              UIApplication.shared.open(url, options: [:], completionHandler: nil)
            #else
              NSWorkspace.shared.open(url)
            #endif
          case .none, .custom:
            break
          }
        default:
          #if canImport(UIKit)
            if UIApplication.shared.canOpenURL(url) {
              UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
          #else
            NSWorkspace.shared.open(url)
          #endif
        }
      }

      decisionHandler(WKNavigationActionPolicy.cancel)
    }
  }
}

extension WebView {
  /// Loads HTML content into the WebView safely on main thread
  /// - Parameter webView: The WKWebView instance to load content into
  private func loadHTML(in webView: WKWebView) {
    Task { @MainActor in
      let htmlString = generateHTML()

      webViewLogger.debug("Loading HTML content (\(htmlString.count) characters)")

      webView.loadHTMLString(htmlString, baseURL: conf.baseURL)
    }
  }

  /// Generates the complete HTML string for the WebView
  /// - Returns: Complete HTML document string
  func generateHTML() -> String {
    return String(
      format: RichTextConstants.htmlTemplate,
      generateCSS(),
      RichTextConstants.richTextContainerID,
      html,
      RichTextConstants.heightNotificationHandler,
      RichTextConstants.richTextContainerID,
      RichTextConstants.mediaClickHandler,
      RichTextConstants.mediaClickHandler
    )
  }

  /// Generates CSS styles based on color scheme configuration
  /// - Returns: CSS string wrapped in style tags
  func generateCSS() -> String {
    switch conf.colorScheme {
    case .light:
      return String(
        format: RichTextConstants.cssTemplate,
        conf.css(isLight: true, alignment: alignment),
        conf.customCSS
      )
    case .dark:
      return String(
        format: RichTextConstants.cssTemplate,
        conf.css(isLight: false, alignment: alignment),
        conf.customCSS
      )
    case .auto:
      return String(
        format: RichTextConstants.mediaCSSTemplate,
        conf.css(isLight: true, alignment: alignment),
        conf.css(isLight: false, alignment: alignment),
        conf.customCSS
      )
    }
  }
}
