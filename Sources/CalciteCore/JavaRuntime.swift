import Foundation

public struct JavaRuntime: Equatable, Hashable, Identifiable {
    public let major: Int
    public let path: String
    public var id: String { path }
    public init(major: Int, path: String) {
        self.major = major
        self.path = path
    }
}

public enum JavaSelectionError: Error, Equatable, CustomStringConvertible {
    /// Nothing installed is new enough. Carries what to download.
    case missingRuntime(required: Int, installed: [Int])

    public var description: String {
        switch self {
        case let .missingRuntime(required, installed):
            let have = installed.isEmpty ? "none" : installed.sorted().map(String.init).joined(separator: ", ")
            return "This version needs Java \(required) but only Java \(have) is installed."
        }
    }
}

public enum JavaSelector {
    /// What Java major does this Minecraft version need?
    public static func requiredMajor(for version: VersionMetadata) -> Int {
        version.javaVersion?.majorVersion ?? LegacyJavaTable.requiredMajor(forVersionID: version.id)
    }

    /// Pick the best installed runtime.
    ///
    /// Rule: exact match first, otherwise the *lowest newer* runtime. Never a
    /// lower one. Silently falling back to an older Java is the exact bug that
    /// crashed Minecraft 26.x on Amethyst (Java 17 loading class file version 69),
    /// so a missing runtime is an error the UI turns into a one-tap download.
    public static func select(for version: VersionMetadata,
                              from installed: [JavaRuntime]) throws -> JavaRuntime {
        let required = requiredMajor(for: version)
        if let exact = installed.first(where: { $0.major == required }) { return exact }
        if let newer = installed.filter({ $0.major > required }).min(by: { $0.major < $1.major }) {
            return newer
        }
        throw JavaSelectionError.missingRuntime(required: required,
                                                installed: installed.map(\.major))
    }
}
