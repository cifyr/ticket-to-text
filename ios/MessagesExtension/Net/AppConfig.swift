import Foundation

enum AppConfig {
    // Flip to true to use the cheat-proof authoritative server. Requires either
    // Deployment Protection turned OFF on the Vercel project, or a bypassToken.
    // Default false keeps the offline (serverless payload) mode working.
    static let useServer = true

    static let serverBaseURL = URL(string: "https://ticket-to-text.vercel.app")!

    // Vercel "Protection Bypass for Automation" secret, if you keep protection on.
    static let bypassToken: String? = nil
}
