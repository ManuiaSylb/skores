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

  factory Game.fromMap(Map<String, dynamic> map) {
    return Game(
      id: map['id'],
      date: map['date'],
      players: [], // La liste des joueurs sera remplie plus tard
    );
  }
}