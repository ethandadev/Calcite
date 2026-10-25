import Foundation

/// The slice of a Mojang version JSON that Calcite needs to choose a Java runtime.
/// Every Minecraft version JSON carries `javaVersion.majorVersion`; that value,
/// not a hard-coded table, is the source of truth.
public struct VersionMetadata: Decodable, Equatable {
    public struct JavaVersion: Decodable, Equatable {
        public let component: String?
        public let majorVersion: Int
    }

    public let id: String
    public let javaVersion: JavaVersion?

    public init(id: String, javaVersion: JavaVersion?) {
        self.id = id
        self.javaVersion = javaVersion
    }
}

public enum LegacyJavaTable {
    /// Fallback for very old version JSONs that predate the `javaVersion` field
    /// (anything before 1.17 has none). Modern versions never use this.
    public static func requiredMajor(forVersionID id: String) -> Int {
        let parts = id.split(separator: ".").compactMap { Int($0.prefix(while: \.isNumber)) }
        guard parts.count >= 2 else { return 8 }
        // New-style year versions (26.1, 26.3 ...) need Java 25.
        if parts[0] >= 26 { return 25 }
        let minor = parts[1], patch = parts.count > 2 ? parts[2] : 0
        if minor >= 21 { return 21 }
        if minor == 20 && patch >= 5 { return 21 }
        if minor >= 18 { return 17 }
        if minor == 17 { return 16 }
        return 8
    }
}
