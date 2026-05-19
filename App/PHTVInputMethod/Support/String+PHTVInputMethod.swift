import Foundation

extension String {
    var isPHTVInputComposableText: Bool {
        unicodeScalars.allSatisfy { scalar in
            CharacterSet.letters.contains(scalar) || PHTVInputMethodCharacterSets.inputMarkers.contains(scalar)
        }
    }

    var isPHTVInputCommitBoundary: Bool {
        unicodeScalars.allSatisfy { scalar in
            CharacterSet.whitespacesAndNewlines.contains(scalar) || CharacterSet.punctuationCharacters.contains(scalar)
        }
    }
}

private enum PHTVInputMethodCharacterSets {
    static let inputMarkers = CharacterSet(charactersIn: "sfrxjzSFRXJZ0123456789")
}
