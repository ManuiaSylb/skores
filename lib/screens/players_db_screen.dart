import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/player.dart';

class PlayersDbScreen extends StatefulWidget {
  const PlayersDbScreen({super.key});

  @override
  State<PlayersDbScreen> createState() => _PlayersDbScreenState();
}

class _PlayersDbScreenState extends State<PlayersDbScreen> {
  List<Player> players = [];
  List<Player> filteredPlayers = [];
  Set<int> selectedPlayers = {};
  bool selectionMode = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    final data = await DatabaseHelper.instance.getAllPlayers();
    setState(() {
      players = data;
      filteredPlayers = data;
    });
  }

  void _filterPlayers(String query) {
    setState(() {
      filteredPlayers = players
          .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _deleteSelectedPlayers() async {
    final db = DatabaseHelper.instance;
    for (var id in selectedPlayers) {
      await db.database.then(
        (db) => db.delete('players', where: 'id = ?', whereArgs: [id]),
      );
    }
    setState(() {
      selectionMode = false;
      selectedPlayers.clear();
    });
    _loadPlayers();
  }

  void _showAddPlayerDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ajouter un joueur'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          autocorrect: true,
          decoration: const InputDecoration(hintText: 'Nom du joueur'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await DatabaseHelper.instance.insertPlayer(Player(name: name));
                _loadPlayers();
              }
              Navigator.pop(context);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Base de joueurs'),
        actions: [
          if (selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSelectedPlayers,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  selectionMode = false;
                  selectedPlayers.clear();
                });
              },
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddPlayerDialog,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _filterPlayers,
              decoration: InputDecoration(
                hintText: 'Rechercher un joueur...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: filteredPlayers.isEmpty
                ? const Center(child: Text('Aucun joueur trouvé'))
                : ListView.builder(
                    itemCount: filteredPlayers.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (context, index) {
                      final player = filteredPlayers[index];
                      final isSelected = selectedPlayers.contains(player.id);

                      return GestureDetector(
                        onLongPress: () {
                          setState(() {
                            selectionMode = true;
                            selectedPlayers.add(player.id!);
                          });
                        },
                        onTap: selectionMode
                            ? () {
                                setState(() {
                                  if (isSelected) {
                                    selectedPlayers.remove(player.id!);
                                  } else {
                                    selectedPlayers.add(player.id!);
                                  }
                                });
                              }
                            : null,
                        child: Card(
                          color: Colors.white,
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: selectionMode
                                ? Checkbox(
                                    value: isSelected,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          selectedPlayers.add(player.id!);
                                        } else {
                                          selectedPlayers.remove(player.id!);
                                        }
                                      });
                                    },
                                  )
                                : const Icon(Icons.person_outline),
                            title: Text(
                              player.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}