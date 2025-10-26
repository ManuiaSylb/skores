class Game {
  final int? id;
  final String date;
  List<String> players;

  Game({this.id, required this.date, required this.players});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'players': '', // Ce champ n'est plus utilisé
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