import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/game.dart';
import '../models/player.dart';
import 'game_screen.dart';

class SelectPlayersScreen extends StatefulWidget {
  final Game game;
  const SelectPlayersScreen({super.key, required this.game});

  @override
  State<SelectPlayersScreen> createState() => _SelectPlayersScreenState();
}

class _SelectPlayersScreenState extends State<SelectPlayersScreen> {
  List<Player> allPlayers = [];
  Set<int> selectedPlayers = {};
  final TextEditingController _newPlayerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    final data = await DatabaseHelper.instance.getAllPlayers();
    setState(() => allPlayers = data);
  }

  Future<void> _addPlayer() async {
  final name = _newPlayerController.text.trim();
  if (name.isEmpty) return;

  final db = DatabaseHelper.instance;
  await db.insertPlayer(Player(name: name));

  // Recharge la liste des joueurs
  await _loadPlayers();

  // Sélectionner automatiquement le joueur ajouté
  final addedPlayer = allPlayers.firstWhere((p) => p.name == name, orElse: () => Player(id: null, name: ''));
  if (addedPlayer.id != null) {
    setState(() {
      selectedPlayers.add(addedPlayer.id!);
    });
  }

  _newPlayerController.clear();
  }

  Future<void> _startGame() async {
    if (selectedPlayers.length < 2 || selectedPlayers.length > 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis entre 2 et 6 joueurs.')),
      );
      return;
    }

    // Insert the game only when the user starts it (if not already persisted)
    int gameId = widget.game.id ??
        await DatabaseHelper.instance.insertGame(widget.game);

    // Link selected players to the newly created game
    for (var pid in selectedPlayers) {
      await DatabaseHelper.instance.linkPlayerToGame(gameId, pid);
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(gameId: gameId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sélection des joueurs')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: allPlayers.map((p) {
                final selected = selectedPlayers.contains(p.id);
                return CheckboxListTile(
                  title: Text(p.name),
                  value: selected,
                  onChanged: (_) {
                    setState(() {
                      if (selected) {
                        selectedPlayers.remove(p.id);
                      } else {
                        selectedPlayers.add(p.id!);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newPlayerController,
                    textCapitalization: TextCapitalization.words,
                    autocorrect: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addPlayer(),
                    decoration: const InputDecoration(
                      labelText: 'Nouveau joueur',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addPlayer,
                  child: const Text('Ajouter'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: _startGame,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Démarrer la partie'),
            ),
          )
        ],
      ),
    );
  }
}