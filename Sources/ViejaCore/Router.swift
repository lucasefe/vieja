import Foundation

public enum Target: Equatable {
    case app(String)
    case prompt

    init(_ id: String) { self = id == "prompt" ? .prompt : .app(id) }
}

public enum Router {
    static let trackingParams: Set<String> = [
        "fbclid", "gclid", "gclsrc", "dclid", "msclkid", "twclid", "igshid", "yclid",
        "mc_cid", "mc_eid", "_hsenc", "_hsmi", "hsCtaTracking", "mkt_tok", "oly_anon_id",
        "oly_enc_id", "vero_id", "wickedid", "ref_src", "ref_url", "s_kwcid", "si", "_ga",
        "sr_share", "spm", "cvid", "ocid", "ncid",
    ]

    public static func stripTracking(_ url: URL, extra: [String] = []) -> URL {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = comps.queryItems, !items.isEmpty else { return url }
        let extraSet = Set(extra)
        let kept = items.filter { item in
            let n = item.name
            return !(n.hasPrefix("utm_") || trackingParams.contains(n) || extraSet.contains(n))
        }
        if kept.count == items.count { return url }
        comps.queryItems = kept.isEmpty ? nil : kept
        return comps.url ?? url
    }

    public static func resolve(_ url: URL, optionHeld: Bool, config: Config) -> Target {
        if optionHeld { return Target(config.alternativeBrowser) }
        let s = url.absoluteString
        for rule in config.rules {
            // ponytail: regex compiled per call; cache if rules list ever gets long
            if s.range(of: rule.match, options: [.regularExpression, .caseInsensitive]) != nil {
                return Target(rule.browser)
            }
        }
        return Target(config.defaultBrowser)
    }
}
