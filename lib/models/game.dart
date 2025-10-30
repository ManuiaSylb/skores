class Game {
  final int? id;
  final String date;
  List<String> players;

  Game({this.id, required this.date, List<String>? players})
      : players = players ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
    };
  }

  /// Calcule qui est le distributeur pour une manche donnée
  /// La distribution commence par le premier joueur (ordre 0) et tourne
  /// dans le sens des aiguilles d'une montre.
  int getDealer(int mancheNum) {
    if (players.isEmpty) return 0;
    // mancheNum commence à 1, on soustrait 1 pour commencer à 0
    return (mancheNum - 1) % players.length;
  }

  factory Game.fromMap(Map<String, dynamic> map) {
    return Game(
      id: map['id'],
      date: map['date'],
      players: [], // La liste des joueurs sera remplie plus tard
    );
  }
}