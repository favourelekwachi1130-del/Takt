import Foundation

/// Public web domain for **Universal Links** — host `apple-app-site-association` on this domain (see `WebHostingTemplate/`).
enum TaktWebLink {
    /// Canonical host used in shared URLs (no `www`).
    static let canonicalHost = "takt-app.org"

    /// `https://takt-app.org/import?p=<base64url(JSON)>`
    static var importPath: String { "/import" }
}

/// Builds shareable **HTTPS** links on **takt-app.org** (opens in Takt via Universal Links) and still accepts legacy `takt://` links.
enum TaktPresetURL {
    static let scheme = "takt"
    static let hostImport = "import"

    // MARK: - Share

    /// Primary share URL: **`https://takt-app.org/import?p=…`** (Universal Link when the domain is configured).
    static func shareURL(for preset: Preset) throws -> URL {
        let p = try encodedPayloadBase64URL(for: preset)
        var c = URLComponents()
        c.scheme = "https"
        c.host = TaktWebLink.canonicalHost
        c.path = TaktWebLink.importPath
        c.queryItems = [URLQueryItem(name: "p", value: p)]
        guard let url = c.url else {
            throw URLError(.badURL)
        }
        return url
    }

    /// Legacy custom-scheme link (still imported by the app): `takt://import?p=…`
    static func legacyDeepLinkURL(for preset: Preset) throws -> URL {
        let p = try encodedPayloadBase64URL(for: preset)
        var c = URLComponents()
        c.scheme = scheme
        c.host = hostImport
        c.queryItems = [URLQueryItem(name: "p", value: p)]
        guard let url = c.url else {
            throw URLError(.badURL)
        }
        return url
    }

    private static func encodedPayloadBase64URL(for preset: Preset) throws -> String {
        let data = try JSONEncoder.takt.encode(preset)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Import

    /// Parses **`https://takt-app.org/import?p=…`**, **`https://www.takt-app.org/...`**, or **`takt://import?p=…`**.
    static func importPreset(from url: URL) throws -> Preset {
        guard let raw = extractPayloadParameter(from: url), !raw.isEmpty else {
            throw URLError(.badURL)
        }
        let padded = padBase64URL(raw)
        guard let data = Data(base64Encoded: padded) else {
            throw URLError(.cannotDecodeRawData)
        }
        return try JSONDecoder.takt.decode(Preset.self, from: data)
    }

    private static func extractPayloadParameter(from url: URL) -> String? {
        let scheme = url.scheme?.lowercased() ?? ""

        if scheme == TaktPresetURL.scheme, url.host == hostImport {
            return queryItemP(from: url)
        }

        if scheme == "https" || scheme == "http" {
            guard isApprovedWebHost(url.host) else { return nil }
            guard pathMatchesImport(url.path) else { return nil }
            return queryItemP(from: url)
        }

        return nil
    }

    private static func queryItemP(from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "p" })?
            .value
    }

    private static func isApprovedWebHost(_ host: String?) -> Bool {
        guard let h = host?.lowercased() else { return false }
        return h == TaktWebLink.canonicalHost || h == "www.\(TaktWebLink.canonicalHost)"
    }

    private static func pathMatchesImport(_ path: String) -> Bool {
        if path == TaktWebLink.importPath { return true }
        if path == "\(TaktWebLink.importPath)/" { return true }
        if path.hasPrefix("\(TaktWebLink.importPath)/") { return true }
        return false
    }

    private static func padBase64URL(_ s: String) -> String {
        let rem = s.count % 4
        if rem == 0 { return s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/") }
        let pad = String(repeating: "=", count: 4 - rem)
        return (s + pad).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    }
}

private extension JSONEncoder {
    static var takt: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

private extension JSONDecoder {
    static var takt: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
