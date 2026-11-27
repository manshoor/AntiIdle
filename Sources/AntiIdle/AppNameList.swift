import Foundation

/// Converts between the App Switch text field and the stored app names.
/// Example: " Safari ,VS Code," <-> ["Safari", "VS Code"].
enum AppNameList {
    private static let separator: Character = ","
    private static let joiner = ", "

    static func parse(_ text: String) -> [String] {
        return text
            .split(separator: separator)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func format(_ names: [String]) -> String {
        return names.joined(separator: joiner)
    }
}
