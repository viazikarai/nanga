import Foundation

extension Array where Element == String {
    func uniquePrefix(_ maxCount: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in self {
            guard !value.isEmpty, !seen.contains(value) else { continue }
            seen.insert(value)
            result.append(value)
            if result.count == maxCount {
                break
            }
        }

        return result
    }
}
