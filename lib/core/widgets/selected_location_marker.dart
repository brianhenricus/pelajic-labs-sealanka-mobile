import 'package:flutter/material.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';

/// Small pulsing-ring dot marking the point a nullschool-style map (wind,
/// currents) is currently showing details for -- device location by
/// default, or wherever the user last tapped.
class SelectedLocationDot extends StatelessWidget {
  const SelectedLocationDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.coralGold,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.coralGold.withOpacity(0.6),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
