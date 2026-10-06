// Shared tile for the Collection screen (collection_screen.dart). Used for
// all three of its tabs — army units, towers, and bestiary enemies — so the
// three tabs read as one consistent gallery/codex rather than three
// differently-styled lists. Purely presentational: the screen decides what
// counts as "locked" for each entry type and hands this widget the result.
//
// A locked entry is shown as a silhouette — lock icon instead of the real
// icon, name replaced with "???", stats and flavor text hidden — so filling
// in the collection by unlocking things elsewhere in the game feels like a
// reveal instead of just a status flag flipping.
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'sprite_thumb.dart';

class CollectionEntryCard extends StatelessWidget {
  final IconData icon;
  final String? spriteName; // when given, the real picture replaces the icon
  final Color accentColor;
  final String name;
  final String statsLine;
  final String flavorText;
  final bool locked;
  final String? lockedHint;

  const CollectionEntryCard({
    super.key,
    required this.icon,
    this.spriteName,
    required this.accentColor,
    required this.name,
    required this.statsLine,
    required this.flavorText,
    required this.locked,
    this.lockedHint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.deepPurple,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: locked ? Colors.white24 : accentColor.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          spriteName != null
              ? UnitAvatar(
                  spriteName: spriteName!,
                  radius: 30,
                  locked: locked,
                  lockedDim: 0.85, // undiscovered = near-black silhouette
                  accent: locked ? Colors.white : accentColor,
                  fallbackIcon: icon,
                )
              : CircleAvatar(
                  radius: 26,
                  backgroundColor: (locked ? Colors.white : accentColor).withValues(alpha: 0.15),
                  child: Icon(
                    locked ? Icons.lock : icon,
                    color: locked ? Colors.white54 : accentColor,
                    size: 26,
                  ),
                ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locked ? '???' : name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontSize: 16, color: locked ? Colors.white54 : AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  locked ? (lockedHint ?? 'Not discovered yet') : statsLine,
                  style: TextStyle(
                    color: locked ? Colors.white38 : AppColors.royalGold,
                    fontSize: 12,
                    fontStyle: locked ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                if (!locked) ...[
                  const SizedBox(height: 4),
                  Text(
                    flavorText,
                    style: const TextStyle(color: AppColors.cyan, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
