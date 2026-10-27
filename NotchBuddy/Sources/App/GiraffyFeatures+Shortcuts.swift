import Foundation

extension GiraffyFeatures {
    /// Whether a shortcut is offered in Giraffy: the wardrobe and the voice command are not.
    static func offers(_ action: ShortcutAction) -> Bool {
        switch action {
        case .wardrobeToggle: return outfits
        case .talkToCoucou: return wakeWord
        default: return true
        }
    }
}
