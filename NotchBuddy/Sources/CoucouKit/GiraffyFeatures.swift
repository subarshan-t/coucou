import Foundation

/// Coucou features Giraffy does not offer (brief, phase 5). Their code stays compiled for now,
/// but none of it is reachable: the pills can't be turned on, their settings are hidden,
/// their pollers and controllers never start, so they make no network calls. Deleting the
/// code is a later clean-up, done where the app can be built and tried.
enum GiraffyFeatures {
    /// Pills that are not offered. The IDs stay reserved: never reuse them for something else.
    static let removedPillIds: Set<String> = [
        "integration_whatsapp",
        "integration_crypto", "integration_portfolio",
        "integration_music", "integration_spotify",
        "integration_stripe", "integration_n8n", "integration_resend",
        "integration_notion", "integration_calcom",
    ]

    /// Stripe, n8n, Resend, Notion, Cal.com, crypto, portfolio and WhatsApp settings and pollers.
    static let removedIntegrations = false

    /// "OK Coucou" voice command: needs a Giraffy phrase before it can come back.
    static let wakeWord = false

    /// The outfit wardrobe was made for Mochi; Giraffy gets his own accessories later.
    static let outfits = false
}
