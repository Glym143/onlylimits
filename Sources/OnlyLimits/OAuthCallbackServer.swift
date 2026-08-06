import Foundation
import Network

/// Minimal localhost HTTP server (Network.framework, no third-party deps).
/// Listens on a fixed port, captures the browser redirect
/// `/auth/callback?code=...&state=...`, returns a small success page, and
/// delivers the query dict exactly once.
final class OAuthCallbackServer {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.local.codexusagebar.oauth")
    private var onCallback: (([String: String]) -> Void)?
    private var didDeliver = false
    private(set) var port: UInt16 = 0

    /// Try each port in order; bind the first available one.
    func start(ports: [UInt16], onCallback: @escaping ([String: String]) -> Void) -> UInt16? {
        self.onCallback = onCallback
        self.didDeliver = false
        for p in ports where startListener(on: p) {
            self.port = p
            return p
        }
        return nil
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func startListener(on port: UInt16) -> Bool {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return false }
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        let listener: NWListener
        do { listener = try NWListener(using: params, on: nwPort) }
        catch { return false }

        let sema = DispatchSemaphore(value: 0)
        var ready = false
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready: ready = true; sema.signal()
            case .waiting, .failed, .cancelled: sema.signal()
            default: break
            }
        }
        listener.newConnectionHandler = { [weak self] conn in self?.handle(conn) }
        listener.start(queue: queue)

        _ = sema.wait(timeout: .now() + 2)
        if ready { self.listener = listener; return true }
        listener.cancel()
        return false
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let self, let data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel(); return
            }
            let query = self.parseQuery(request)
            let isCallback = query["code"] != nil || query["error"] != nil
            let body = isCallback ? Self.successHTML(ok: query["code"] != nil) : "not found"
            let status = isCallback ? "200 OK" : "404 Not Found"
            let response = "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
            connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
                connection.cancel()
            })
            if isCallback && !self.didDeliver {
                self.didDeliver = true
                self.onCallback?(query)
            }
        }
    }

    /// Extract query params from the HTTP request line `GET /auth/callback?...`.
    private func parseQuery(_ request: String) -> [String: String] {
        guard let line = request.split(separator: "\r\n").first else { return [:] }
        let parts = line.split(separator: " ")
        guard parts.count >= 2, let comps = URLComponents(string: "http://localhost\(parts[1])") else { return [:] }
        var out: [String: String] = [:]
        for item in comps.queryItems ?? [] { out[item.name] = item.value }
        return out
    }

    private static func successHTML(ok: Bool) -> String {
        let title = ok ? "✓ Signed in" : "✗ Sign-in failed"
        let msg = ok ? "You can close this tab and return to OnlyLimits." : "Something went wrong. Return to the app and try again."
        return """
        <!doctype html><html><head><meta charset="utf-8"><title>\(title)</title>
        <style>body{font-family:-apple-system,system-ui,sans-serif;background:#111;color:#eee;
        display:flex;height:100vh;margin:0;align-items:center;justify-content:center}
        .card{text-align:center;padding:40px 48px;background:#1c1c1e;border-radius:16px}
        h1{font-size:20px;margin:0 0 8px}p{color:#aaa;margin:0}</style></head>
        <body><div class="card"><h1>\(title)</h1><p>\(msg)</p></div></body></html>
        """
    }
}
