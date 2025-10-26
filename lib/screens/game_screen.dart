import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/player.dart';

class GameScreen extends StatefulWidget {
  final int gameId;
  const GameScreen({super.key, required this.gameId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  List<Player> players = [];

  // Structure : mancheData[manche][playerId] = { 'pari': x, 'plis': y, 'bonus': z }
  final Map<int, Map<int, Map<String, int?>>> mancheData = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final playersData = await DatabaseHelper.instance.getPlayersForGame(
      widget.gameId,
    );
    final scoresData = await DatabaseHelper.instance.getAllMancheScores(
      widget.gameId,
    );

    setState(() {
      players = playersData;
      mancheData.addAll(scoresData);
    });
  }

  @override
  Widget build(BuildContext context) {
    const mancheCount = 10;

    return WillPopScope(
      onWillPop: () async {
        // Sauvegarde complète avant de quitter la page
        await _saveAllMancheData();
        return true;
      },
      child: Scaffold(
       backgroundColor: Colors.grey[255],
       appBar: AppBar(
         elevation: 0,
         backgroundColor: const Color.fromARGB(255, 89, 40, 28),
         leading: IconButton(
           icon: const Icon(Icons.close, color: Colors.white),
           onPressed: () async {
             // save before exiting
             await _saveAllMancheData();
             if (mounted) Navigator.pop(context);
           },
         ),
         title: Text(
           'Manche ${_currentPage + 1}/$mancheCount',
           style: const TextStyle(color: Colors.white,fontWeight: FontWeight.w600),
         ),
         centerTitle: true,
         actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: _currentPage > 0
                ? () => _controller.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  )
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
            onPressed: _currentPage < mancheCount - 1
                ? () => _controller.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  )
                : null,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: mancheCount,
        onPageChanged: (i) => setState(() => _currentPage = i),
        itemBuilder: (context, index) => _buildManchePage(index + 1),
      ),
      ),
    );
  }

  Future<void> _saveAllMancheData() async {
    // iterate through all mancheData and persist each player's data
    for (var mancheEntry in mancheData.entries) {
      final mancheNum = mancheEntry.key;
      final playersMap = mancheEntry.value;
      for (var playerEntry in playersMap.entries) {
        final playerId = playerEntry.key;
        final data = playerEntry.value;
        // ensure map values are non-null ints where possible
        await DatabaseHelper.instance.saveMancheScore(
          widget.gameId,
          playerId,
          mancheNum,
          data,
        );
      }
    }
  }

  Widget _buildManchePage(int mancheNum) {
    final columnTitles = ['Joueur', 'Pari', 'Plis', 'Bonus', 'Total'];

    // options dynamiques selon la manche
    final pariOptions = List.generate(mancheNum + 1, (i) => i);
    final plisOptions = List.generate(mancheNum + 1, (i) => i);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: columnTitles
                  .map(
                    (title) => Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          // lignes joueurs
          ...players.map((p) {
            mancheData.putIfAbsent(mancheNum, () => {});
            mancheData[mancheNum]!.putIfAbsent(p.id!, () => {});

            final data = mancheData[mancheNum]![p.id!]!;
            final pari = data['pari'];
            final plis = data['plis'];
            final bonus = data['bonus'] ?? 0;

            // score total cumulé toutes manches
            final totalScore = _calculateTotalScore(p.id!);

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Joueur
                  Expanded(
                    child: Text(
                      p.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  // Pari
                  Expanded(
                    child: _buildDropdown(
                      value: pari,
                      items: pariOptions,
                      onChanged: (val) =>
                          _updateMancheValue(mancheNum, p.id!, 'pari', val),
                    ),
                  ),
                  // Plis
                  Expanded(
                    child: _buildDropdown(
                      value: plis,
                      items: plisOptions,
                      onChanged: (val) =>
                          _updateMancheValue(mancheNum, p.id!, 'plis', val),
                    ),
                  ),
                  // Bonus
                  Expanded(
                    child: Builder(builder: (context) {
                      final canEditBonus = pari != null && plis != null && pari == plis;

                      return Tooltip(
                        message: canEditBonus
                            ? 'Modifier le bonus'
                            : 'Le bonus est disponible uniquement si pari == plis',
                        child: TextButton(
                          onPressed: canEditBonus
                              ? () => _showBonusDialog(mancheNum, p.id!, bonus)
                              : null,
                          child: Text(
                            bonus > 0 ? '$bonus' : '-',
                            style: TextStyle(
                              color: bonus > 0 ? const Color.fromARGB(255, 81, 81, 81) : const Color.fromARGB(255, 81, 81, 81),
                              fontWeight: bonus > 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  // Score total
                  Expanded(
                    child: Text(
                      '$totalScore',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 152, 42, 6),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required int? value,
    required List<int> items,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: value,
        hint: const Text('-'),
        isExpanded: true,
        items: items
            .map(
              (v) => DropdownMenuItem<int>(
                value: v,
                child: Center(child: Text(v.toString())),
              ),
            )
            .toList(),
        onChanged: (val) => setState(() => onChanged(val)),
      ),
    );
  }

  void _showBonusDialog(int mancheNum, int playerId, int currentBonus) {
    // Récupérer les valeurs existantes
    final data = mancheData[mancheNum]?[playerId] ?? {};
    int coloredFourteens =
        data['colored_fourteens'] ?? 0; // 10 points chaque (0-3)
    int blackFourteen =
        data['black_fourteen'] ?? 0; // 20 points si présent (0-1)
    int capturedMermaids =
        data['captured_mermaids'] ?? 0; // 20 points chaque (0-2)
    int capturedPirates =
        data['captured_pirates'] ?? 0; // 30 points chaque (0-5)
    int skullKingCaptured =
        data['skullking_captured'] ?? 0; // 40 points si présent (0-1)

    void updateAllBonusValues() {
      final totalBonus =
          coloredFourteens * 10 +
          blackFourteen * 20 +
          capturedMermaids * 20 +
          capturedPirates * 30 +
          skullKingCaptured * 40;

      _updateBonusValues(
        mancheNum,
        playerId,
        totalBonus,
        bonusDetails: {
          'colored_fourteens': coloredFourteens,
          'black_fourteen': blackFourteen,
          'captured_mermaids': capturedMermaids,
          'captured_pirates': capturedPirates,
          'skullking_captured': skullKingCaptured,
        },
      );
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            int calculateTotalBonus() {
              return coloredFourteens * 10 +
                  blackFourteen * 20 +
                  capturedMermaids * 20 +
                  capturedPirates * 30 +
                  skullKingCaptured * 40;
            }

            return AlertDialog(
              title: const Text('Détail des bonus'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 14 de couleurs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(child: Text('14 de couleurs :')),
                      DropdownButton<int>(
                        value: coloredFourteens,
                        items: List.generate(
                          4,
                          (i) => DropdownMenuItem(value: i, child: Text('$i')),
                        ),
                        onChanged: (val) {
                          setState(() => coloredFourteens = val!);
                          updateAllBonusValues();
                        },
                      ),
                    ],
                  ),
                  // 14 noir
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(child: Text('14 noir :')),
                      DropdownButton<int>(
                        value: blackFourteen,
                        items: List.generate(
                          2,
                          (i) => DropdownMenuItem(value: i, child: Text('$i')),
                        ),
                        onChanged: (val) {
                          setState(() => blackFourteen = val!);
                          updateAllBonusValues();
                        },
                      ),
                    ],
                  ),
                  // Sirènes capturées
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(child: Text('Sirènes capturées :')),
                      DropdownButton<int>(
                        value: capturedMermaids,
                        items: List.generate(
                          3,
                          (i) => DropdownMenuItem(value: i, child: Text('$i')),
                        ),
                        onChanged: (val) {
                          setState(() => capturedMermaids = val!);
                          updateAllBonusValues();
                        },
                      ),
                    ],
                  ),
                  // Pirates capturés
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(child: Text('Pirates capturés :')),
                      DropdownButton<int>(
                        value: capturedPirates,
                        items: List.generate(
                          6,
                          (i) => DropdownMenuItem(value: i, child: Text('$i')),
                        ),
                        onChanged: (val) {
                          setState(() => capturedPirates = val!);
                          updateAllBonusValues();
                        },
                      ),
                    ],
                  ),
                  // Skull King capturé
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(child: Text('Skull King capturé :')),
                      DropdownButton<int>(
                        value: skullKingCaptured,
                        items: List.generate(
                          2,
                          (i) => DropdownMenuItem(value: i, child: Text('$i')),
                        ),
                        onChanged: (val) {
                          setState(() => skullKingCaptured = val!);
                          updateAllBonusValues();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bonus: ${calculateTotalBonus()} points',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fermer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _updateBonusValues(
    int manche,
    int playerId,
    int totalBonus, {
    required Map<String, int> bonusDetails,
  }) {
    setState(() {
      mancheData.putIfAbsent(manche, () => {});
      mancheData[manche]!.putIfAbsent(playerId, () => {});

      // Mettre à jour tous les champs de bonus
      mancheData[manche]![playerId]!.addAll({
        'bonus': totalBonus,
        ...bonusDetails,
      });
    });

    // Sauvegarder immédiatement dans la base de données
    DatabaseHelper.instance.saveMancheScore(
      widget.gameId,
      playerId,
      manche,
      mancheData[manche]![playerId]!,
    );
  }

  void _updateMancheValue(int manche, int playerId, String key, int? value) {
    setState(() {
      mancheData.putIfAbsent(manche, () => {});
      mancheData[manche]!.putIfAbsent(playerId, () => {});
      mancheData[manche]![playerId]![key] = value;
    });
    
    // Sauvegarde automatique après chaque modification
    DatabaseHelper.instance.saveMancheScore(
      widget.gameId,
      playerId,
      manche,
      mancheData[manche]![playerId]!,
    );
  }

  int _calculateTotalScore(int playerId) {
    int total = 0;

    for (var mancheEntry in mancheData.entries) {
      final mancheNum = mancheEntry.key;
      final data = mancheEntry.value[playerId];
      if (data == null) continue;

      final pari = data['pari'];
      final plis = data['plis'];
      final bonus = data['bonus'] ?? 0;

      if (pari != null && plis != null) {
        if (pari == plis && pari != 0) {
          total += 20 * pari + bonus;
        } else if (pari == 0) {
          if (plis == 0) {
            total += 10 * mancheNum + bonus;
          } else {
            total += -10 * mancheNum;
          }
        } else {
          total += -10 * (pari - plis).abs();
        }
      } else if (bonus != 0) {
        total += bonus;
      }
    }

    return total;
  }
}