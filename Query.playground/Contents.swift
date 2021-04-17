import Cocoa

let versionString = "2.1.0aA"
 
extension String {
    func versionNumber() -> Double {
        let numberString = self.lowercased().trimmingCharacters(in: CharacterSet.lowercaseLetters)
        guard let majorIndex = numberString.range(of: ".") else {
            return 0
        }
        let replaceRange = numberString.startIndex..<majorIndex.lowerBound
        let major = numberString[replaceRange] + "."
        let remainder = numberString.replacingCharacters(in: replaceRange, with: "").replacingOccurrences(of: ".", with: "")
        let composite = major + remainder
        return Double(composite) ?? 0
    }
}

versionString.versionNumber()

let vString = ProcessInfo().operatingSystemVersionString
let vers = ProcessInfo().operatingSystemVersion
let fullVersion = "\(vers.majorVersion).\(vers.minorVersion).\(vers.patchVersion)"
