/// Anything shown as an avatar + name: match players, tournament players, teams.
/// Lets the "N players have joined" banner and the player cards serve every feature.
public protocol HasAvatar {
    var name: String { get }
    var image: String { get }
}

extension MatchPlayer: HasAvatar {}
extension TournamentPlayer: HasAvatar {}
extension ClubBrief: HasAvatar {}
