# Sea Lanka screen-rebuild cheatsheet (design-system fidelity)

Rebuild Flutter screens to match the HTML prototypes in
`D:\Projects\Pelagic_Labs_Products\SeaLanka\sea-lanka-design-system\project\screens\*.html`
and the React kit `...\project\ui_kits\sea-lanka-app\screens\*.jsx`.

## Hard rules
- Use ONLY the tokens/components below. Remove every hardcoded `fontFamily: 'Poppins'`
  and raw `TextStyle(fontSize: ...)`; replace with `AppTextStyles.*`.
- Colors via `AppColors.*`; spacing/radii via `AppSpacing.*`; shadows `AppShadows.*`;
  motion `AppMotion.*`. No magic numbers for spacing/radii.
- NO spinners. Use `LoadingShimmer` / `ShimmerCard` for loading states.
- Do NOT edit shared files (router, DI, mock_*, pubspec, anything in lib/core). Only edit
  the page/widget files you are assigned. Keep existing data sources (bloc or mock/setState)
  exactly as they are — this pass is VISUAL only.
- Keep class names, constructors, and routes unchanged so the router still compiles.
- Keep `flutter analyze` clean: no unused imports/vars, null-safety correct.

## Tokens
`import 'package:sea_lanka/core/constants/app_colors.dart';`
AppColors: midnightNavy, deepSeaBlue, marineBlue, skyBlue, white, coralGold,
coralGoldDeep, sand, success, warning, danger, info, teal, backgroundLight,
backgroundDark, cardLight, cardDark, borderLight, borderDark, fg1, fg2, fg3,
fgOnDark, fgOnDark2, slateText. Probability: probHigh1/2, probMid1/2, probLow1/2.
Gradients (LinearGradient): headerGradient, ctaGradient, fishGradient,
probHighGradient, probMidGradient, probLowGradient.

`import 'package:sea_lanka/core/constants/app_spacing.dart';`
AppSpacing: xs=4, sm=8, md=12, base=16, lg=20, xl=24, xl2=32, xl3=40, xl4=48, xl5=64.
Radii: radiusSm=8, radiusMd=12, radiusLg=16, radiusXl=24, radiusFull=999,
radiusButton=12, radiusInput=12, radiusCard=16, radiusSheet=24.
Sizes: buttonHeight=48, fabSize=56, bottomNavHeight=80, tapMin=44, cardPadding=16,
pagePadding=16, appBarHeight=60.

`import 'package:sea_lanka/core/constants/app_typography.dart';`
AppTextStyles.display/h1/h2/h3/bodyL/body/caption/overline — ALL take a `Locale`:
`final locale = Localizations.localeOf(context);`
`Text('x', style: AppTextStyles.h2(locale).copyWith(color: AppColors.fg1))`
Display 28/H1 24/H2 20/H3 18/BodyL 16/Body 14/Caption 12/Overline 11.
Overline: render the string in UPPERCASE yourself (e.g. `'live'.toUpperCase()`).

`import 'package:sea_lanka/core/constants/app_motion.dart';` AppMotion.page/tap/tapScale/pulse/easeOut.
`import 'package:sea_lanka/core/constants/app_shadows.dart';` AppShadows.card/fab/sheet (List<BoxShadow>).

## Components (lib/core/widgets/, import the specific file)
- SeaLankaHeader(title, subtitle?, leading?, actions?, footer?) — navy gradient hero w/ wave.
  HeaderLocationPill(location) for the footer slot. (sea_lanka_header.dart)
- SeaLankaCard(child, padding?, onTap?, color?, borderRadius?, accentColor?) — 16dp card +
  shadow; accentColor draws 4dp left severity border. (sea_lanka_card.dart)
- SeaLankaButton(label, onPressed, variant: SeaLankaButtonVariant.{primary,cta,secondary,
  outline,ghost}, isLoading, fullWidth, icon, height). cta = gold gradient. (sea_lanka_button.dart)
- SeaLankaFab(icon, onPressed, tooltip?) — 56dp gold gradient + glow. (sea_lanka_fab.dart)
- DataStatusBadge(status: DataStatus.{live,cached,offline}, detail?) — pulsing live dot.
  (data_status_badge.dart)
- MetricTile(icon, value, label, iconColor?) — mini stat. (metric_tile.dart)
- SectionTitle(title, actionLabel?, onAction?). (section_title.dart)
- ZoneTile(tier: ProbabilityTier.{high,medium,low}, name, percent, direction?, distance?,
  onTap?). ProbabilityTierX.fromPercent(num) maps %→tier. (zone_tile.dart)
- ListRow(icon?, iconColor?, title, subtitle?, trailing?, onTap?). (list_row.dart)
- Attribution(color?) — "A Pelagic Labs Product". (attribution.dart)
- SlSegmented(segments: List<String>, selectedIndex, onChanged). (sl_segmented.dart)
- SlTextField(controller?, label?, hint?, prefixIcon?, suffix?, obscureText, keyboardType?,
  validator?, onChanged?, maxLines). (sl_text_field.dart)
- showSlBottomSheet<T>(context:, builder:) — 24dp top radius + handle + lift shadow.
  (sl_bottom_sheet.dart)
- SeaLankaPressable(child, onTap?, borderRadius?) — 0.98 tap scale. (sea_lanka_pressable.dart)
- LoadingShimmer(width?, height?, borderRadius), ShimmerCard(). (loading_shimmer.dart)

## Reference exemplar (already rebuilt to spec)
`lib/features/profile/presentation/pages/profile_page.dart` — shows header gradient,
cards, ListRow settings, stats, shimmer loading, error view, button usage.

## Design language reminders
- App body background AppColors.backgroundLight (flat). Header = navy gradient.
- Sky blue reserved for the FAB only. Coral-gold = the one "next action".
- Probability tiers use gradients (ZoneTile), never flat fills.
- Sentence case for labels; UPPERCASE only for overline status (LIVE/OFFLINE/HIGH).
- Metric values always carry units: "12 kn SW", "2.4 m", "28 °C", 24h time "04:32".
