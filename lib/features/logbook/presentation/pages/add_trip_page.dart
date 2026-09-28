import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/core/di/injection_container.dart';
import 'package:sea_lanka/core/location/location_service.dart';
import 'package:sea_lanka/core/network/network_info.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_app_bar.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_button.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_card.dart';
import 'package:sea_lanka/core/widgets/sl_text_field.dart';
import 'package:sea_lanka/features/logbook/data/datasources/logbook_remote_datasource.dart';
import 'package:sea_lanka/features/logbook/data/repositories/logbook_repository_impl.dart';
import 'package:sea_lanka/features/logbook/domain/entities/catch_entry.dart';
import 'package:sea_lanka/features/logbook/domain/usecases/create_trip_usecase.dart';
import 'package:sea_lanka/features/logbook/domain/usecases/get_trips_usecase.dart';
import 'package:sea_lanka/features/logbook/presentation/bloc/logbook_bloc.dart';

class AddTripPage extends StatelessWidget {
  const AddTripPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = LogbookRepositoryImpl(
      remoteDataSource: LogbookRemoteDataSourceImpl(sl<Dio>()),
      networkInfo: sl<NetworkInfo>(),
    );
    return BlocProvider(
      create: (_) => LogbookBloc(
        getTrips: GetTripsUseCase(repository),
        createTrip: CreateTripUseCase(repository),
      ),
      child: const _AddTripView(),
    );
  }
}

class _AddTripView extends StatefulWidget {
  const _AddTripView();

  @override
  State<_AddTripView> createState() => _AddTripViewState();
}

class _AddTripViewState extends State<_AddTripView> {
  final _formKey = GlobalKey<FormState>();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _notesController = TextEditingController();
  final _hoursController = TextEditingController();
  final _minutesController = TextEditingController();
  final _fuelController = TextEditingController();
  DateTime _tripDate = DateTime.now();
  final List<Map<String, dynamic>> _catches = [];
  final List<XFile> _photos = [];
  bool _uploadingPhotos = false;

  // Raw datasource, not routed through the bloc -- uploading is a
  // prerequisite step (turning picked files into URLs) the bloc's
  // create-trip flow doesn't need to know about, same pattern as this
  // app's other direct-datasource secondary operations.
  final _photoDataSource = LogbookRemoteDataSourceImpl(sl<Dio>());

  @override
  void initState() {
    super.initState();
    _prefillPosition();
  }

  // Zone is recorded as the trip's actual lat/lon (editable, in case the GPS
  // fix is off or the fisherman wants to log a different spot) rather than a
  // free-text zone name -- avoids a name that doesn't match where the trip
  // actually happened, and a second silent GPS call at submit time that
  // could disagree with whatever the user typed.
  Future<void> _prefillPosition() async {
    final (lat, lon) = await sl<LocationService>().getLatLonOrDefault();
    if (!mounted) return;
    setState(() {
      _latController.text = lat.toStringAsFixed(4);
      _lonController.text = lon.toStringAsFixed(4);
    });
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _notesController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _fuelController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() => _photos.addAll(picked));
  }

  void _addCatch() {
    showDialog(
      context: context,
      builder: (context) => _AddCatchDialog(
        onAdd: (species, weight, quantity) {
          setState(() {
            _catches.add({
              'species': species,
              'weight': weight,
              'quantity': quantity,
            });
          });
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _tripDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _tripDate = d);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final lat = double.parse(_latController.text);
    final lon = double.parse(_lonController.text);

    List<String> photoUrls = const [];
    if (_photos.isNotEmpty) {
      setState(() => _uploadingPhotos = true);
      try {
        photoUrls = await Future.wait(
            _photos.map((p) => _photoDataSource.uploadPhoto(p.path)));
      } catch (_) {
        if (mounted) {
          setState(() => _uploadingPhotos = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(AppLocalizations.of(context)!.photosUploadFailed)));
        }
        return;
      }
      if (!mounted) return;
      setState(() => _uploadingPhotos = false);
    }

    final hours = int.tryParse(_hoursController.text) ?? 0;
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final fuel = double.tryParse(_fuelController.text);

    if (!mounted) return;
    context.read<LogbookBloc>().add(TripSubmitted(CreateTripParams(
          date: _tripDate,
          location: '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}',
          lat: lat,
          lon: lon,
          catches: _catches
              .map((c) => CatchEntry(
                    species: c['species'] as String,
                    weightKg: (c['weight'] as num).toDouble(),
                    quantity: c['quantity'] as int,
                  ))
              .toList(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          photoUrls: photoUrls,
          durationMinutes: hours * 60 + minutes,
          fuelLiters: fuel,
        )));
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    final isSubmitting = context.watch<LogbookBloc>().state is TripSubmissionInProgress;
    return BlocListener<LogbookBloc, LogbookState>(
      listener: (context, state) {
        if (state is TripSubmissionSuccess) {
          context.pop();
        } else if (state is TripSubmissionFailure) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: SeaLankaAppBar(title: l10n.newTripEntry),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [
            Text(l10n.tripDetails,
                style: AppTextStyles.h3(locale).copyWith(color: AppColors.fg1)),
            const SizedBox(height: AppSpacing.md),
            SeaLankaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date picker
                  _DateField(
                    value: DateFormat('MMM d, yyyy').format(_tripDate),
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SlTextField(
                          controller: _latController,
                          label: l10n.zoneLatitude,
                          hint: '0.0000',
                          prefixIcon: Icons.location_on_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          validator: (v) {
                            final d = double.tryParse(v ?? '');
                            if (d == null || d < -90 || d > 90) return l10n.invalidValue;
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: SlTextField(
                          controller: _lonController,
                          label: l10n.zoneLongitude,
                          hint: '0.0000',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          validator: (v) {
                            final d = double.tryParse(v ?? '');
                            if (d == null || d < -180 || d > 180) return l10n.invalidValue;
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SlTextField(
                          controller: _hoursController,
                          label: l10n.durationHours,
                          hint: '0',
                          prefixIcon: Icons.schedule_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: SlTextField(
                          controller: _minutesController,
                          label: l10n.minutes,
                          hint: '0',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.base),
                  SlTextField(
                    controller: _fuelController,
                    label: l10n.fuelUsedOptional,
                    hint: '0.0',
                    prefixIcon: Icons.local_gas_station_outlined,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  SlTextField(
                    controller: _notesController,
                    label: l10n.notesOptional,
                    prefixIcon: Icons.notes_rounded,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.photos,
                    style: AppTextStyles.h3(locale)
                        .copyWith(color: AppColors.fg1)),
                TextButton.icon(
                  onPressed: _pickPhotos,
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: Text(l10n.add),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_photos.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.cardLight,
                  border: Border.all(color: AppColors.borderLight),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                ),
                child: Center(
                  child: Text(l10n.noPhotosAddedYet,
                      style: AppTextStyles.body(locale)
                          .copyWith(color: AppColors.fg3)),
                ),
              )
            else
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        child: Image.file(
                          File(_photos[i].path),
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _photos.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.midnightNavy,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.catches,
                    style: AppTextStyles.h3(locale)
                        .copyWith(color: AppColors.fg1)),
                TextButton.icon(
                  onPressed: _addCatch,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.add),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_catches.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.cardLight,
                  border: Border.all(color: AppColors.borderLight),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                ),
                child: Center(
                  child: Text(l10n.noCatchesAddedYet,
                      style: AppTextStyles.body(locale)
                          .copyWith(color: AppColors.fg3)),
                ),
              )
            else
              SeaLankaCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base, vertical: AppSpacing.xs),
                child: Column(
                  children: _catches.asMap().entries.map((entry) {
                    final catch_ = entry.value;
                    return _CatchRow(
                      species: catch_['species'] as String,
                      subtitle: l10n.catchSubtitle(
                          '${catch_['weight']}', '${catch_['quantity']}'),
                      onDelete: () =>
                          setState(() => _catches.removeAt(entry.key)),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
            SeaLankaButton(
              label: l10n.saveTrip,
              variant: SeaLankaButtonVariant.cta,
              icon: Icons.check_rounded,
              isLoading: isSubmitting || _uploadingPhotos,
              onPressed: (isSubmitting || _uploadingPhotos) ? null : _submit,
            ),
            const SizedBox(height: AppSpacing.sm),
            SeaLankaButton(
              label: l10n.cancel,
              variant: SeaLankaButtonVariant.ghost,
              onPressed: (isSubmitting || _uploadingPhotos)
                  ? null
                  : () => context.pop(),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String value;
  final VoidCallback onTap;
  const _DateField({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.date,
            style: AppTextStyles.caption(locale).copyWith(
              color: AppColors.fg2,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            decoration: BoxDecoration(
              color: AppColors.cardLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusInput),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 18, color: AppColors.marineBlue),
                const SizedBox(width: AppSpacing.md),
                Text(value,
                    style: AppTextStyles.bodyL(locale)
                        .copyWith(color: AppColors.fg1)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CatchRow extends StatelessWidget {
  final String species;
  final String subtitle;
  final VoidCallback onDelete;
  const _CatchRow(
      {required this.species,
      required this.subtitle,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.teal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: const Icon(Icons.set_meal_rounded,
                color: AppColors.teal, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(species,
                    style: AppTextStyles.bodyL(locale)
                        .copyWith(color: AppColors.fg1)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppTextStyles.caption(locale)
                        .copyWith(color: AppColors.fg3)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.danger),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _AddCatchDialog extends StatefulWidget {
  final void Function(String species, double weight, int count) onAdd;

  const _AddCatchDialog({required this.onAdd});

  @override
  State<_AddCatchDialog> createState() => _AddCatchDialogState();
}

class _AddCatchDialogState extends State<_AddCatchDialog> {
  final _speciesController = TextEditingController();
  final _weightController = TextEditingController();
  final _countController = TextEditingController(text: '1');

  @override
  void dispose() {
    _speciesController.dispose();
    _weightController.dispose();
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: AppColors.cardLight,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard)),
      title: Text(l10n.addCatch,
          style: AppTextStyles.h3(locale).copyWith(color: AppColors.fg1)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SlTextField(
            controller: _speciesController,
            label: l10n.species,
            hint: l10n.speciesHint,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SlTextField(
                  controller: _weightController,
                  label: l10n.catchWeight,
                  hint: '0.0 kg',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: SlTextField(
                  controller: _countController,
                  label: l10n.count,
                  hint: '0',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        SeaLankaButton(
          label: l10n.cancel,
          variant: SeaLankaButtonVariant.ghost,
          fullWidth: false,
          onPressed: () => Navigator.pop(context),
        ),
        SeaLankaButton(
          label: l10n.add,
          variant: SeaLankaButtonVariant.primary,
          fullWidth: false,
          onPressed: () {
            widget.onAdd(
              _speciesController.text,
              double.tryParse(_weightController.text) ?? 0,
              int.tryParse(_countController.text) ?? 1,
            );
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
