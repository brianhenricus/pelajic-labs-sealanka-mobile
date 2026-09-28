import 'package:flutter/material.dart';

/// One color-coded speed band for a particle-flow legend (wind speed in
/// km/h, current speed in m/s) — shared between [ParticleFlowLayer]'s
/// per-particle coloring and [SpeedLegend] so the two always agree.
class SpeedTier {
  final String label;
  final String rangeLabel;
  final Color color;
  final double minValue; // inclusive, in the tier set's display unit
  const SpeedTier(this.label, this.rangeLabel, this.color, this.minValue);
}

/// Wind speed tiers in km/h, matching the app's wind-map legend.
const List<SpeedTier> kWindSpeedTiers = [
  SpeedTier('Calm', '<5', Color(0xFFE8ECF2), 0),
  SpeedTier('Light', '5-15', Color(0xFF2DD4BF), 5),
  SpeedTier('Moderate', '15-38', Color(0xFF34D399), 15),
  SpeedTier('Strong', '38-58', Color(0xFFFBBF24), 38),
  SpeedTier('Storm', '>58', Color(0xFFEF4444), 58),
];

/// Ocean current speed tiers in m/s, matching the app's current-map legend.
const List<SpeedTier> kCurrentSpeedTiers = [
  SpeedTier('Slow', '<0.2', Color(0xFF64748B), 0),
  SpeedTier('Light', '0.2-0.5', Color(0xFF2DD4BF), 0.2),
  SpeedTier('Moderate', '0.5-1', Color(0xFF22D3EE), 0.5),
  SpeedTier('Fast', '1-2', Color(0xFFA78BFA), 1.0),
  SpeedTier('Strong', '>2', Color(0xFF7C3AED), 2.0),
];

/// Looks up the tier color for a speed value (tiers must be sorted
/// ascending by minValue, as the two constants above are).
Color colorForSpeed(List<SpeedTier> tiers, double value) {
  var color = tiers.first.color;
  for (final tier in tiers) {
    if (value >= tier.minValue) color = tier.color;
  }
  return color;
}

/// Small translucent legend box (top-right overlay on a particle-flow map)
/// listing each speed tier's color, name, and range — matches the
/// nullschool-style wind/current map mockups.
class SpeedLegend extends StatelessWidget {
  final String title;
  final List<SpeedTier> tiers;
  const SpeedLegend({super.key, required this.title, required this.tiers});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          for (final tier in tiers)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: tier.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(tier.label,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 11)),
                  const SizedBox(width: 8),
                  Text(tier.rangeLabel,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
