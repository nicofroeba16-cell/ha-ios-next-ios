import Foundation

struct ProfileDefinition: Equatable, Sendable {
    let profile: HomeProfile
    let roomNames: [String]
    let favoriteEntityIDs: [String]
}

enum ProfileCatalog {
    static func definition(for profile: HomeProfile) -> ProfileDefinition {
        switch profile {
        case .timo:
            ProfileDefinition(
                profile: .timo,
                roomNames: ["Timo Zimmer"],
                favoriteEntityIDs: [
                    "light.hintergrund_fernseher",
                    "light.nachttisch",
                    "light.schlafzimmer",
                    "media_player.schlafzimmer"
                ]
            )
        case .mika:
            ProfileDefinition(
                profile: .mika,
                roomNames: ["Mika Zimmer"],
                favoriteEntityIDs: ["media_player.fire_tv_192_168_178_54"]
            )
        case .juli:
            ProfileDefinition(profile: .juli, roomNames: ["Juli Zimmer"], favoriteEntityIDs: [])
        case .gabi:
            ProfileDefinition(profile: .gabi, roomNames: ["Zuhause"], favoriteEntityIDs: [])
        }
    }
}
