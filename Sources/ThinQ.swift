import Foundation

let defaults = UserDefaults.standard
struct LGError: LocalizedError {
  let message: String
  var errorDescription: String? { message }
}
func object(_ value: Any) -> [String: Any] { value as? [String: Any] ?? [:] }
func find(_ key: String, in value: Any) -> Any? {
  if let d = value as? [String: Any] {
    if let v = d[key] { return v }
    for v in d.values { if let r = find(key, in: v) { return r } }
  }
  if let a = value as? [Any] { for v in a { if let r = find(key, in: v) { return r } } }
  return nil
}
func celsius(_ value: Any) -> [String: Any] {
  if let a = value as? [[String: Any]] { return a.first { ($0["unit"] as? String) == "C" } ?? [:] }
  let d = object(value)
  return (d["unit"] as? String) == "F" ? [:] : d
}
func equal(_ a: Any, _ b: Any) -> Bool {
  if let x = a as? NSNumber, let y = b as? NSNumber { return x == y }
  return String(describing: a) == String(describing: b)
}
func number(_ value: Any?) -> Double? { (value as? NSNumber)?.doubleValue }
func degree(_ value: Double?) -> String {
  guard let v = value else { return "—" }
  return v == v.rounded() ? String(format: "%.0f°", v) : String(format: "%.1f°", v)
}
enum TokenFile {
  static var url: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support/LGBar/token.txt")
  }
  static func read() -> String {
    if let saved = try? String(contentsOf: url, encoding: .utf8).trimmingCharacters(
      in: .whitespacesAndNewlines), !saved.isEmpty
    {
      return saved
    }
    guard let bundled = Bundle.main.url(forResource: "token", withExtension: "txt") else {
      return ""
    }
    return (try? String(contentsOf: bundled, encoding: .utf8))?.trimmingCharacters(
      in: .whitespacesAndNewlines) ?? ""
  }
  static func save(_ token: String) throws {
    let folder = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(
      at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    try Data(token.utf8).write(to: url, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
  }
}

final class API {
  let token: String, country: String, region: String, client: String
  init() {
    token = TokenFile.read()
    country = defaults.string(forKey: "country") ?? "PH"
    region = defaults.string(forKey: "region") ?? "kic"
    client = defaults.string(forKey: "client") ?? UUID().uuidString
    defaults.set(client, forKey: "client")
  }
  func request(_ path: String, payload: [String: Any]? = nil) async throws -> Any {
    guard !token.isEmpty else { throw LGError(message: "No token configured") }
    guard let url = URL(string: "https://api-\(region).lgthinq.com/\(path)") else {
      throw LGError(message: "Invalid API address")
    }
    var r = URLRequest(url: url)
    r.timeoutInterval = 20
    r.httpMethod = payload == nil ? "GET" : "POST"
    var uuid = UUID().uuid
    let message = withUnsafeBytes(of: &uuid) { Data($0) }.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
    let headers = [
      "Authorization": "Bearer \(token)", "x-country": country, "x-client-id": client,
      "x-message-id": message, "x-service-phase": "OP",
      "x-api-key": "ZkVkqP9jq44HuWkbNX9EKzZmmn7ToPY3A4vQ4tY8", "Content-Type": "application/json",
    ]
    for (k, v) in headers { r.setValue(v, forHTTPHeaderField: k) }
    if let p = payload {
      r.setValue("true", forHTTPHeaderField: "x-conditional-control")
      r.httpBody = try JSONSerialization.data(withJSONObject: p)
    }
    let (data, response) = try await URLSession.shared.data(for: r)
    guard let h = response as? HTTPURLResponse else {
      throw LGError(message: "No response from LG")
    }
    guard (200..<300).contains(h.statusCode) else {
      throw LGError(message: "LG HTTP \(h.statusCode). Check token, country and region.")
    }
    if data.isEmpty { return [:] as [String: Any] }
    let json = try JSONSerialization.jsonObject(with: data)
    if let e = object(json)["error"] {
      throw LGError(message: "LG: \(object(e)["code"] ?? "error")")
    }
    return object(json)["response"] ?? json
  }
}
struct Device {
  let id: String
  let name: String
  var imageURL: URL? = nil
}
func applianceURL(_ info: Any) -> URL? {
  for key in ["imageUrl", "imageURL", "deviceImageUrl", "productImageUrl", "modelImageUrl"] {
    if let s = find(key, in: info) as? String, let u = URL(string: s), u.scheme == "https" {
      return u
    }
  }
  return nil
}
func liveWatts(_ value: Any) -> Double? {
  for key in ["currentPower", "instantaneousPower", "powerConsumptionW", "currentPowerConsumption"]
  {
    guard let raw = find(key, in: value) else { continue }
    let reading = object(raw)
    let quantity = reading["value"] ?? raw
    guard let n = number(quantity) ?? (quantity as? String).flatMap(Double.init), n.isFinite, n >= 0
    else { continue }
    switch (reading["unit"] as? String ?? "W").lowercased() {
    case "w", "watt", "watts": return n
    case "kw", "kilowatt", "kilowatts": return 1000 * n
    default: continue
    }
  }
  return nil
}
func energyTotal(_ value: Any) -> Double? {
  let result = object(object(value)["result"] ?? value)
  if let n = number(result["total"]) { return n }
  if let n = number(result["energyUsage"]) { return n }
  if let n = number(result["value"]) { return n }
  for key in ["dataList", "usage", "data", "values", "energyUsage", "details"] {
    if let a = result[key] as? [Any], !a.isEmpty {
      let readings = a.compactMap { v -> Double? in
        if let n = number(v) { return n }
        let d = object(v)
        return number(d["value"] ?? d["energyUsage"] ?? d["usage"])
      }
      if readings.count == a.count { return readings.reduce(0, +) }
    }
  }
  return nil
}
