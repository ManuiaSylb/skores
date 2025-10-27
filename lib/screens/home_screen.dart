import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/game.dart';
import '../widgets/game_card.dart';
import 'select_players_screen.dart';
import 'game_screen.dart';
import 'players_db_screen.dart'; // nouvel écran pour la gestion des joueurs

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Game> games = [];
  Set<int> selectedGames = {}; // IDs des parties sélectionnées
  bool selectionMode = false;  // active les cases à cocher

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    final data = await DatabaseHelper.instance.getAllGames();
    setState(() => games = data);
  }

  void _createNewGame() async {
    // Create an in-memory Game object but don't persist it yet.
    final newGame = Game(
      id: null,
      date: DateFormat('yyyy-MM-dd – kk:mm').format(DateTime.now()),
      players: [],
    );

    // Navigate to select players screen. The game will be inserted only when
    // the user taps "Démarrer la partie" in the selection screen.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectPlayersScreen(game: newGame),
      ),
    ).then((_) => _loadGames());
  }

  void _openGame(Game game) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(gameId: game.id!),
      ),
    );
  }

  void _deleteSelectedGames() async {
    final db = DatabaseHelper.instance;
    for (var id in selectedGames) {
      final database = await db.database;
      await database.delete(
        'manche_scores',
        where: 'game_id = ?',
        whereArgs: [id],
      );
      await database.delete(
        'game_players',
        where: 'game_id = ?',
        whereArgs: [id],
      );
      await database.delete('games', where: 'id = ?', whereArgs: [id]);
    }
    setState(() {
      selectedGames.clear();
      selectionMode = false;
    });
    _loadGames();
  }

  void _openPlayersDb() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlayersDbScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200], // fond gris clair
      appBar: AppBar(
        title: const Text('SKores : Skull King Scores'),
        actions: [
          if (selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSelectedGames,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  selectionMode = false;
                  selectedGames.clear();
                });
              },
            ),
          ] else ...[
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'select') {
                  setState(() => selectionMode = true);
                } else if (value == 'players') {
                  _openPlayersDb();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'select',
                  child: Text('Sélectionner des parties'),
                ),
                const PopupMenuItem(
                  value: 'players',
                  child: Text('Voir la base de joueurs'),
                ),
              ],
            ),
          ],
        ],
      ),
      body: games.isEmpty
          ? const Center(child: Text('Aucune partie enregistrée'))
          : ListView.builder(
              itemCount: games.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final game = games[index];
                final isSelected = selectedGames.contains(game.id);

                return GestureDetector(
                  onLongPress: () {
                    setState(() {
                      selectionMode = true;
                      selectedGames.add(game.id!);
                    });
                  },
                  child: GameCard(
                    game: game,
                    selectionMode: selectionMode,
                    isSelected: isSelected,
                    onCheckboxChanged: (val) {
                      setState(() {
                        if (val == true) {
                          selectedGames.add(game.id!);
                        } else {
                          selectedGames.remove(game.id!);
                        }
                      });
                    },
                    onTap: selectionMode
                        ? () {
                            setState(() {
                              if (isSelected) {
                                selectedGames.remove(game.id!);
                              } else {
                                selectedGames.add(game.id!);
                              }
                            });
                          }
                        : () => _openGame(game),
                  ),
                );
              },
            ),
      floatingActionButton: !selectionMode
          ? FloatingActionButton(
              onPressed: _createNewGame,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}