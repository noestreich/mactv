import Foundation

// Holt die echte ZDF-HLS-URL über die offizielle ZDF-API.
// Wird von Swift aus aufgerufen (kein CORS-Problem) und das Ergebnis
// per evaluateJavaScript an WKWebView übergeben.
final class ZDFLoader {

    private static let token     = "ahBaeMeekaiy5ohsai4bee4ki6Oopoi5quailieb"
    private static let playerID  = "ngplayer_2_4"
    private static let canonical = "zdf-live-beitrag-100"

    static func fetchHLSURL(completion: @escaping (String?) -> Void) {

        // Schritt 1: GraphQL → ptmdTemplate
        var gql = URLRequest(url: URL(string: "https://api.zdf.de/graphql")!)
        gql.httpMethod = "POST"
        gql.setValue("Bearer \(token)", forHTTPHeaderField: "api-auth")
        gql.setValue("application/json",   forHTTPHeaderField: "content-type")
        gql.setValue("https://www.zdf.de/", forHTTPHeaderField: "referer")
        gql.httpBody = try? JSONSerialization.data(withJSONObject: [
            "operationName": "VideoByCanonical",
            "query": "query VideoByCanonical($canonical:String!){videoByCanonical(canonical:$canonical){currentMedia{nodes{ptmdTemplate id}}}}",
            "variables": ["canonical": canonical]
        ])

        URLSession.shared.dataTask(with: gql) { data, _, _ in
            guard
                let data,
                let root   = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let nodes  = (((root["data"] as? [String: Any])?["videoByCanonical"]
                               as? [String: Any])?["currentMedia"]
                               as? [String: Any])?["nodes"] as? [[String: Any]],
                let ptmd   = nodes.first?["ptmdTemplate"] as? String
            else { DispatchQueue.main.async { completion(nil) }; return }

            // Schritt 2: Stream-Metadaten → HLS-URL
            let path = ptmd.replacingOccurrences(of: "{playerId}", with: playerID)
            var meta = URLRequest(url: URL(string: "https://api.zdf.de" + path)!)
            meta.setValue("Bearer \(token)",                                   forHTTPHeaderField: "Api-Auth")
            meta.setValue("application/vnd.de.zdf.v1.0+json;charset=UTF-8",   forHTTPHeaderField: "Accept")
            meta.setValue("https://www.zdf.de/",                               forHTTPHeaderField: "Referer")

            URLSession.shared.dataTask(with: meta) { data, _, _ in
                guard
                    let data,
                    let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let list = root["priorityList"] as? [[String: Any]]
                else { DispatchQueue.main.async { completion(nil) }; return }

                var hlsURL: String?
                outer: for prio in list {
                    for form in (prio["formitaeten"] as? [[String: Any]]) ?? [] {
                        guard form["type"] as? String == "h264_aac_ts_http_m3u8_http" else { continue }
                        for qual in (form["qualities"] as? [[String: Any]]) ?? [] {
                            guard qual["quality"] as? String == "auto",
                                  let uri = ((qual["audio"] as? [String: Any])?["tracks"]
                                             as? [[String: Any]])?.first?["uri"] as? String
                            else { continue }
                            hlsURL = uri
                            break outer
                        }
                    }
                }
                DispatchQueue.main.async { completion(hlsURL) }
            }.resume()
        }.resume()
    }
}
