// Central color palette for Kingdom Wars: Castle Defense.
// Keep ALL raw color values here — screens/widgets should reference
// AppColors.xxx rather than hardcoding hex values.
//
// Palette: gold / brown / green (parchment-and-forest medieval feel).
// Buttons intentionally use a different accent (rust/terracotta) so they
// stand out from the background instead of blending into it.
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Browns (background/surface family — replaces the old purple family;
  // field names kept so every existing reference across the app still works).
  static const Color deepPurple = Color(0xFF4A3220); // mid-tone wood brown — surfaces, cards
  static const Color darkPurple = Color(0xFF241608); // near-black brown — app background

  // Gold (primary accent — titles, borders, currency)
  static const Color royalGold = Color(0xFFE0A82E);
  static const Color lightGold = Color(0xFFF2CE7C);
  // Bright, shiny gold used for the Settings (gear) icon.
  static const Color goldIcon = Color(0xFFFFC823);

  // Greens (good/friendly accent)
  static const Color emeraldGood = Color(0xFF2E7D32);

  // Reds (danger/enemy — kept vivid for contrast against the earthy palette)
  static const Color crimsonEvil = Color(0xFFB71C1C);

  // Secondary accents
  static const Color cyan = Color(0xFF3D9970); // mossy teal-green (mage magic, was pure cyan)
  static const Color orange = Color(0xFFC96A1B); // embers/fire, sits inside the brown family
  static const Color diamondBlue = Color(0xFF3E8FB0); // muted slate-blue, only used for gem icons
  static const Color chestBrown = Color(0xFF6B4423);

  // Buttons: a distinct rust/terracotta so interactive elements pop instead
  // of blending into the gold/brown/green background.
  static const Color buttonPrimary = Color(0xFFA5432A);
  static const Color buttonPrimaryPressed = Color(0xFF7C3120);

  // Derived / semantic aliases used across screens.
  static const Color background = darkPurple;
  static const Color surface = deepPurple;
  static const Color goodHealthBar = crimsonEvil; // your castle HP bar (red per spec)
  static const Color enemyHealthBar = emeraldGood; // enemy castle HP bar (green per spec)
  static const Color textPrimary = Colors.white;
  static const Color textGold = royalGold;

  static const List<Color> goldGradient = [royalGold, lightGold];
  static const List<Color> menuBackgroundGradient = [darkPurple, deepPurple];
}
