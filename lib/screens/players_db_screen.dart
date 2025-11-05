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

  Future<void> _showPlayerStats(Player player) async {
    final allStats = await DatabaseHelper.instance.getAllPlayerStats();
    final playerStats = allStats[player.id] ?? {};

    final gamesPlayed = playerStats.keys.length;
    int totalPoints = 0;
    int totalWins = 0;

    for (final gameMap in playerStats.values) {
      totalPoints += gameMap['player_final_score'] ?? 0;
      totalWins += gameMap['win'] ?? 0;
    }

    final mancheStats = await DatabaseHelper.instance.getPlayerMancheStats(
      player.id!,
    );

    List<double> avgBets = [];
    List<double> avgPlis = [];

    for (int manche = 1; manche <= 10; manche++) {
      if (mancheStats.containsKey(manche)) {
        final betsList = mancheStats[manche]!['paris']!;
        final plisList = mancheStats[manche]!['plis']!;

        if (betsList.isNotEmpty && plisList.isNotEmpty) {
          final avgBet = betsList.reduce((a, b) => a + b) / betsList.length;
          final avgPli = plisList.reduce((a, b) => a + b) / plisList.length;

          avgBets.add(avgBet);
          avgPlis.add(avgPli);
        } else {
          avgBets.add(0);
          avgPlis.add(0);
        }
      } else {
        avgBets.add(0);
        avgPlis.add(0);
      }
    }

showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  if (gamesPlayed > 0) ...[
                    const SizedBox(height: 12),
                    Text('Parties jouées : $gamesPlayed'),
                    Text('Victoires : $totalWins'),
                    Text('Total de points : $totalPoints'),
                    const SizedBox(height: 12),
                    const Text('Évolution Paris / Plis par manche :'),
                    const SizedBox(height: 6),
                    _buildLineChart(avgBets, avgPlis),
                  ] else
                    const Text("Aucune donnée enregistrée."),

                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Fermer'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLineChart(List<double> avgBets, List<double> avgPlis) {
    return Container(
      height: 280,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: LineChartPainter(avgBets, avgPlis),
        child: Container(),
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
              icon: Icon(
                Icons.delete,
                color: selectedPlayers.isEmpty ? Colors.grey : null,
              ),
              onPressed: selectedPlayers.isEmpty
                  ? null
                  : _deleteSelectedPlayers,
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
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'select') {
                  setState(() => selectionMode = true);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'select',
                  child: Text('Sélectionner des joueurs'),
                ),
              ],
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
                            : () => _showPlayerStats(player),
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
      floatingActionButton: !selectionMode
          ? FloatingActionButton(
              onPressed: _showAddPlayerDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<double> avgBets;
  final List<double> avgPlis;

  LineChartPainter(this.avgBets, this.avgPlis);

  @override
  void paint(Canvas canvas, Size size) {
    final betPaint = Paint()
      ..color = const Color.fromARGB(255, 89, 40, 28)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final plisPaint = Paint()
      ..color = const Color.fromARGB(255, 183, 83, 17)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pointPaint = Paint()..style = PaintingStyle.fill;

    final textPaint = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    const margin = 50.0;
    final chartWidth = size.width - margin * 2;
    final chartHeight = size.height - margin * 2;

    final axisPaint = Paint()
      ..color = Colors.grey[600]!
      ..strokeWidth = 1.5;

    final gridPaint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 0.8;

    for (int i = 0; i < 10; i++) {
      final x = margin + (i * chartWidth / 9);
      canvas.drawLine(
        Offset(x, margin),
        Offset(x, size.height - margin),
        gridPaint,
      );
    }

    for (int i = 0; i <= 10; i++) {
      final y = size.height - margin - (i * chartHeight / 10);
      canvas.drawLine(
        Offset(margin, y),
        Offset(size.width - margin, y),
        gridPaint,
      );
    }

    canvas.drawLine(
      Offset(margin, size.height - margin),
      Offset(size.width - margin, size.height - margin),
      axisPaint,
    );

    canvas.drawLine(
      Offset(margin, margin),
      Offset(margin, size.height - margin),
      axisPaint,
    );

    for (int i = 0; i < 10; i++) {
      final x = margin + (i * chartWidth / 9);
      textPaint.text = TextSpan(
        text: '${i + 1}',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[700],
          fontWeight: FontWeight.w500,
        ),
      );
      textPaint.layout();
      textPaint.paint(
        canvas,
        Offset(x - textPaint.width / 2, size.height - margin + 12),
      );
    }

    // Étiquettes axe Y (0-10)
    for (int i = 0; i <= 10; i++) {
      final y = size.height - margin - (i * chartHeight / 10);
      textPaint.text = TextSpan(
        text: '$i',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[700],
          fontWeight: FontWeight.w500,
        ),
      );
      textPaint.layout();
      textPaint.paint(canvas, Offset(12, y - textPaint.height / 2));
    }

    textPaint.text = const TextSpan(
      text: 'Numéro de la manche',
      style: TextStyle(
        fontSize: 12,
        color: Color.fromARGB(255, 71, 71, 71),
        fontWeight: FontWeight.w500,
      ),
    );
    textPaint.layout();
    textPaint.paint(
      canvas,
      Offset(margin + chartWidth / 2 - textPaint.width / 2, size.height - 8),
    );

    Offset getPoint(int index, double value) {
      final x = margin + (index * chartWidth / 9);
      final y = size.height - margin - (value * chartHeight / 10);
      return Offset(x, y);
    }

    Path createSmoothPath(List<double> values) {
      final path = Path();
      if (values.isEmpty) return path;

      final points = <Offset>[];
      for (int i = 0; i < values.length; i++) {
        points.add(getPoint(i, values[i]));
      }

      if (points.length == 1) {
        path.addOval(Rect.fromCircle(center: points[0], radius: 3));
        return path;
      }

      path.moveTo(points[0].dx, points[0].dy);

      for (int i = 1; i < points.length; i++) {
        final p0 = i > 1 ? points[i - 2] : points[i - 1];
        final p1 = points[i - 1];
        final p2 = points[i];
        final p3 = i < points.length - 1 ? points[i + 1] : points[i];

        final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
        final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
        final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
        final cp2y = p2.dy - (p3.dy - p1.dy) / 6;

        path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
      }

      return path;
    }

    final betPath = createSmoothPath(avgBets);
    canvas.drawPath(betPath, betPaint);

    final plisPath = createSmoothPath(avgPlis);
    canvas.drawPath(plisPath, plisPaint);

    for (int i = 0; i < avgBets.length; i++) {
      final betPoint = getPoint(i, avgBets[i]);
      pointPaint.color = const Color.fromARGB(255, 89, 40, 28);
      canvas.drawCircle(betPoint, 3, pointPaint);

      final plisPoint = getPoint(i, avgPlis[i]);
      pointPaint.color = const Color.fromARGB(255, 183, 83, 17);
      canvas.drawCircle(plisPoint, 3, pointPaint);
    }

    final legendY = 25.0;
    canvas.drawLine(
      Offset(margin, legendY),
      Offset(margin + 30, legendY),
      betPaint,
    );
    textPaint.text = const TextSpan(
      text: 'Paris',
      style: TextStyle(
        fontSize: 14,
        color: Color.fromARGB(255, 89, 40, 28),
        fontWeight: FontWeight.w600,
      ),
    );
    textPaint.layout();
    textPaint.paint(canvas, Offset(margin + 35, legendY - 7));

    canvas.drawLine(
      Offset(margin + 120, legendY),
      Offset(margin + 150, legendY),
      plisPaint,
    );
    textPaint.text = const TextSpan(
      text: 'Plis',
      style: TextStyle(
        fontSize: 14,
        color: const Color.fromARGB(255, 183, 83, 17),
        fontWeight: FontWeight.w600,
      ),
    );
    textPaint.layout();
    textPaint.paint(canvas, Offset(margin + 155, legendY - 7));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
