import 'package:flutter/material.dart';

/// Colour tokens — mirrors the COLOR block of `colors_and_type.css`.
class AppColors {
  AppColors._();

  // — Brand core (locked to logo) —
  static const midnightNavy = Color(0xFF0A1F44); // --sl-midnight
  static const deepSeaBlue = Color(0xFF1B3A7A); // --sl-deep-sea
  static const marineBlue = Color(0xFF2E6FD9); // --sl-marine
  static const skyBlue = Color(0xFF5BA8E8); // --sl-sky
  static const white = Color(0xFFFFFFFF); // --sl-white

  // — Accent (CTAs, FABs) —
  static const coralGold = Color(0xFFF4A030); // --sl-coral-gold
  static const coralGoldDeep = Color(0xFFE0871C); // --sl-coral-gold-deep
  static const sand = Color(0xFFFCE4B8); // --sl-sand

  // — Semantic —
  static const success = Color(0xFF2BB673); // --sl-success
  static const warning = Color(0xFFF5B400); // --sl-warning
  static const danger = Color(0xFFE63946); // --sl-danger
  static const info = Color(0xFF4DB6E8); // --sl-info
  // Legacy aliases (kept so existing screens compile during the rebuild).
  static const seaGreen = success;
  static const amber = warning;
  static const coralRed = danger;
  static const skyCyan = info;
  static const teal = Color(0xFF0D9B8A);

  // — Surfaces —
  static const backgroundLight = Color(0xFFF5F8FB); // --sl-bg-light
  static const backgroundDark = Color(0xFF0A1F44); // --sl-bg-dark
  static const cardLight = Color(0xFFFFFFFF); // --sl-card-light
  static const cardDark = Color(0xFF142A50); // --sl-card-dark
  static const borderLight = Color(0xFFE2E8F0); // --sl-border
  static const borderDark = Color(0xFF1E3A6E); // --sl-border-dark

  // — Foreground (text) —
  static const fg1 = Color(0xFF0A1F44); // primary on light
  static const fg2 = Color(0xFF334155); // secondary on light
  static const fg3 = Color(0xFF64748B); // tertiary / attribution
  static const fgOnDark = Color(0xFFFFFFFF);
  static const fgOnDark2 = Color(0xFFB8C7E0);
  static const slateText = fg3; // legacy alias

  // — Probability tiers —
  static const probHigh1 = Color(0xFFF4C430);
  static const probHigh2 = Color(0xFFF4A030);
  static const probMid1 = Color(0xFFF08A2A);
  static const probMid2 = Color(0xFFE85D1A);
  static const probLow1 = Color(0xFFE63946);
  static const probLow2 = Color(0xFFB22234);

  // — Gradients (--sl-grad-*) —
  static const headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [midnightNavy, deepSeaBlue],
  );
  static const ctaGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF4C430), Color(0xFFF4A030)],
  );
  static const fishGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [skyBlue, deepSeaBlue],
  );
  static const probHighGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [probHigh1, probHigh2],
  );
  static const probMidGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [probMid1, probMid2],
  );
  static const probLowGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [probLow1, probLow2],
  );
}
