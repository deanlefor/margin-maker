import Foundation

/// The packaged Info.plist is the sole authority for version/build/channel.
struct AppVersion {
    static var current: AppVersion { AppVersion(info: Bundle.main.infoDictionary ?? [:]) }

    let label: String

    init(info: [String: Any]) {
        guard let version = info["CFBundleShortVersionString"] as? String, !version.isEmpty,
              let build = info["CFBundleVersion"] as? String, !build.isEmpty else {
            label = "Unbundled development build"
            return
        }
        let channel = info["MarginMakerBuildChannel"] as? String
        let suffix = channel.flatMap { $0.isEmpty || $0 == "Release" ? nil : $0 }
        label = "v\(version)" + (suffix.map { " · \($0)" } ?? "") + " (\(build))"
    }
}
