import Foundation

/// Builds the app-owned script that measures remote HTML documents. Content
/// JavaScript stays disabled; this is the only JavaScript allowed in the view.
enum HTMLWebViewScriptBuilder {
    static func source(
        suppressLongPressInteractions: Bool,
        pressToTapThresholdMs: Int,
        renderGeneration: UInt64
    ) -> String {
        sourceTemplate
            .replacingOccurrences(of: "__PRESS_TO_TAP_THRESHOLD__", with: String(pressToTapThresholdMs))
            .replacingOccurrences(of: "__RENDER_GENERATION__", with: String(renderGeneration))
            .replacingOccurrences(
                of: "__SELECTION_SUPPRESSION__",
                with: suppressLongPressInteractions ? selectionSuppressionSource : ""
            )
    }

    private static let selectionSuppressionSource = """
    document.addEventListener('selectstart', function(e) {
        if (isInsideLink(e.target)) {
            return;
        }
        e.preventDefault();
    }, true);
    """

    private static let sourceTemplate = """
    // Keep the embedded document non-scrollable; the parent SwiftUI
    // ScrollView owns vertical scrolling for feed cells.
    var style = document.createElement('style');
    style.textContent = 'html, body { overflow: hidden !important; } ::-webkit-scrollbar { display: none; }';
    document.getElementsByTagName('head')[0].appendChild(style);

    function computedDocumentHeight() {
        var body = document.body;
        var contentRoot = document.getElementById('content-root');
        var bodyStyle = body ? window.getComputedStyle(body) : null;
        var bodyPaddingTop = bodyStyle ? parseFloat(bodyStyle.paddingTop || '0') : 0;
        var bodyPaddingBottom = bodyStyle ? parseFloat(bodyStyle.paddingBottom || '0') : 0;
        var contentRect = contentRoot ? contentRoot.getBoundingClientRect() : null;
        return Math.ceil(Math.max(
            contentRoot ? contentRoot.scrollHeight : 0,
            contentRoot ? contentRoot.offsetHeight : 0,
            contentRect ? contentRect.height : 0
        ) + bodyPaddingTop + bodyPaddingBottom + 8);
    }

    var pendingHeightFrame = false;
    function reportHeightSoon() {
        if (pendingHeightFrame) {
            return;
        }
        pendingHeightFrame = true;
        requestAnimationFrame(function() {
            pendingHeightFrame = false;
            window.webkit.messageHandlers.heightHandler.postMessage({
                generation: __RENDER_GENERATION__,
                height: computedDocumentHeight()
            });
        });
    }

    function resetScrollPosition() {
        window.scrollTo(0, 0);
        if (document.documentElement) {
            document.documentElement.scrollTop = 0;
        }
        if (document.body) {
            document.body.scrollTop = 0;
        }
    }

    var pressStartTimestamp = 0;
    var ignoreClickUntil = 0;
    function closestAnchor(node) {
        var current = node;
        while (current) {
            if (current.tagName === 'A') {
                return current;
            }
            current = current.parentElement;
        }
        return null;
    }
    function markPressStart(event) {
        pressStartTimestamp = Date.now();
        var anchor = closestAnchor(event.target);
        if (anchor && anchor.href) {
            window.webkit.messageHandlers.linkPressHandler.postMessage(anchor.href);
        } else {
            window.webkit.messageHandlers.linkPressHandler.postMessage("");
        }
    }
    function isInsideLink(node) {
        return closestAnchor(node) !== null;
    }
    document.addEventListener('touchstart', markPressStart, true);
    document.addEventListener('pointerdown', markPressStart, true);
    document.addEventListener('mousedown', markPressStart, true);
    window.addEventListener('load', reportHeightSoon, true);
    window.addEventListener('resize', reportHeightSoon, true);

    function bindImageHeightListeners(root) {
        if (!root) {
            return;
        }
        var images = [];
        if (root.tagName === 'IMG') {
            images.push(root);
        }
        if (root.querySelectorAll) {
            var descendants = root.querySelectorAll('img');
            for (var i = 0; i < descendants.length; i++) {
                images.push(descendants[i]);
            }
        }
        for (var j = 0; j < images.length; j++) {
            var img = images[j];
            if (img.__heightListenerBound) {
                continue;
            }
            img.__heightListenerBound = true;
            img.addEventListener('load', reportHeightSoon, true);
            img.addEventListener('error', reportHeightSoon, true);
        }
    }

    var observer = new MutationObserver(function(mutations) {
        for (var i = 0; i < mutations.length; i++) {
            var mutation = mutations[i];
            for (var j = 0; j < mutation.addedNodes.length; j++) {
                var node = mutation.addedNodes[j];
                if (node && node.nodeType === 1) {
                    bindImageHeightListeners(node);
                }
            }
        }
        reportHeightSoon();
    });
    observer.observe(document.documentElement || document.body, {
        childList: true,
        subtree: true,
        attributes: true,
        characterData: true
    });
    bindImageHeightListeners(document);

    document.addEventListener('click', function(e) {
        if (Date.now() < ignoreClickUntil) {
            return;
        }
        if (pressStartTimestamp > 0 && Date.now() - pressStartTimestamp > __PRESS_TO_TAP_THRESHOLD__) {
            return;
        }
        if (isInsideLink(e.target)) {
            return;
        }
        window.webkit.messageHandlers.tapHandler.postMessage('tap');
        e.preventDefault();
    }, true);
    __SELECTION_SUPPRESSION__
    resetScrollPosition();
    reportHeightSoon();
    """
}
