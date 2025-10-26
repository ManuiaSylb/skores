import 'package:flutter/material.dart';
import '../models/game.dart';

class GameCard extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;
  final bool selectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onCheckboxChanged;

  const GameCard({
    super.key,
    required this.game,
    required this.onTap,
    this.selectionMode = false,
    this.isSelected = false,
    this.onCheckboxChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ListTile(
        leading: selectionMode
            ? Checkbox(
                value: isSelected,
                onChanged: onCheckboxChanged,
              )
            : null,
        title: Text('Partie du ${game.date}'),
        subtitle: Text(
          'Joueurs : ${game.players.isEmpty ? "Non défini" : game.players.join(", ")}',
        ),
        onTap: onTap,
      ),
    );
  }
}