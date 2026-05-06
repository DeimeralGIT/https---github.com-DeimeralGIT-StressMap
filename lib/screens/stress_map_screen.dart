import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/indicator_filters.dart';
import '../models/map_bounds.dart';
import '../models/stress_location.dart';
import '../providers/stress_map_controller.dart';
import '../utils/stress_level.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/legend_card.dart';
import '../widgets/location_detail_card.dart';
import '../widgets/settings_sheet.dart';

class StressMapScreen extends StatefulWidget {
  const StressMapScreen({super.key});

  @override
  State<StressMapScreen> createState() => _StressMapScreenState();
}

class _StressMapScreenState extends State<StressMapScreen> {
  static const _initialCenter = LatLng(20, 0);
  static const _staleViewportDelay = Duration(seconds: 2);
  static const _detailZoomDelay = Duration(milliseconds: 350);
  static const _detailFetchZoom = 10.0;
  static const _immediateZoomDelta = 1.0;
  static const _minimumZoomDelta = 0.25;

  final _mapController = MapController();
  Timer? _viewportDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusCurrentLocation());
  }

  @override
  void dispose() {
    _viewportDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StressMapController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final edgeInsets = EdgeInsets.fromLTRB(
          isWide ? 24 : 14,
          isWide ? 20 : 10,
          isWide ? 24 : 14,
          isWide ? 20 : 12,
        );

        return Stack(
          children: [
            FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _initialCenter,
                  initialZoom: isWide ? 3.0 : 2.4,
                  backgroundColor: const Color(0xFF1E242C),
                  minZoom: 1.6,
                  maxZoom: 17,
                  onMapEvent: _handleMapEvent,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    maxNativeZoom: 20,
                    retinaMode: RetinaMode.isHighDensity(context),
                    userAgentPackageName: 'com.example.stressmap',
                  ),
                  CircleLayer(
                    circles:
                        controller.locations.map(_circleForLocation).toList(),
                  ),
                  MarkerLayer(
                    markers: [
                      ...controller.locations.map((location) {
                        return _markerForLocation(
                          context,
                          location,
                          controller.selectedLocation?.id == location.id,
                          isWide,
                        );
                      }),
                      if (controller.currentLocation != null)
                        _currentLocationMarker(controller.currentLocation!),
                    ],
                  ),
                ],
              ),
            SafeArea(
              child: Padding(
                padding: edgeInsets,
                child: isWide
                    ? _WideOverlay(
                        isLoading: controller.isLoading,
                        mapController: _mapController,
                        onLocate: _focusCurrentLocation,
                        isLocating: controller.isLocating,
                      )
                    : _MobileOverlay(
                        isLoading: controller.isLoading,
                        mapController: _mapController,
                        onLocate: _focusCurrentLocation,
                        isLocating: controller.isLocating,
                      ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: const _AttributionInfoButton(),
            ),
            Positioned(
              top: isWide ? 188 : 182,
              left: 14,
              right: 14,
              child: IgnorePointer(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: controller.shouldShowZoomInTip
                      ? const _ZoomInHintChip()
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleMapEvent(MapEvent event) {
    final camera = _mapController.camera;
    context.read<StressMapController>().updateZoomInTip(
      zoom: camera.zoom,
      bounds: _boundsFromCamera(camera),
    );

    if (event is! MapEventMoveEnd &&
        event is! MapEventFlingAnimationEnd &&
        event is! MapEventDoubleTapZoomEnd) {
      return;
    }

    _scheduleViewportRefresh();
  }

  void _scheduleViewportRefresh() {
    final camera = _mapController.camera;
    final controller = context.read<StressMapController>();

    if (!_isFiniteLatLng(camera.center) || !_isFiniteBounds(camera.visibleBounds)) {
      return;
    }

    if (!_isMeaningfulViewportChange(
      nextCenter: camera.center,
      nextZoom: camera.zoom,
      previousCenter: controller.lastCenter,
      previousZoom: controller.lastZoom,
    )) {
      return;
    }

    final zoomDelta = camera.zoom - controller.lastZoom;
    final isDetailedZoomIn =
        camera.zoom >= _detailFetchZoom && zoomDelta >= _immediateZoomDelta;
    final delay = isDetailedZoomIn ? _detailZoomDelay : _staleViewportDelay;

    _viewportDebounce?.cancel();
    _viewportDebounce = Timer(delay, () {
      if (!mounted) return;
      final settledCamera = _mapController.camera;
      final latestController = context.read<StressMapController>();

      if (!_isMeaningfulViewportChange(
        nextCenter: settledCamera.center,
        nextZoom: settledCamera.zoom,
        previousCenter: latestController.lastCenter,
        previousZoom: latestController.lastZoom,
      )) {
        return;
      }

      if (!_isFiniteLatLng(settledCamera.center) ||
          !_isFiniteBounds(settledCamera.visibleBounds)) {
        return;
      }

      latestController.loadForViewport(
        center: settledCamera.center,
        zoom: settledCamera.zoom,
        bounds: _boundsFromCamera(settledCamera),
      );
    });
  }

  bool _isMeaningfulViewportChange({
    required LatLng nextCenter,
    required double nextZoom,
    required LatLng previousCenter,
    required double previousZoom,
  }) {
    final zoomDelta = (nextZoom - previousZoom).abs();
    if (zoomDelta >= _minimumZoomDelta) return true;

    final movedMeters = _distanceMeters(previousCenter, nextCenter);
    return movedMeters >= _minimumMoveMetersForZoom(nextZoom);
  }

  double _minimumMoveMetersForZoom(double zoom) {
    if (zoom < 4) return 450000;
    if (zoom < 7) return 140000;
    if (zoom < 10) return 28000;
    if (zoom < 13) return 6500;
    return 1400;
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const earthRadiusMeters = 6371000.0;
    final lat1 = _radians(a.latitude);
    final lat2 = _radians(b.latitude);
    final deltaLat = _radians(b.latitude - a.latitude);
    final deltaLng = _radians(b.longitude - a.longitude);
    final sinLat = math.sin(deltaLat / 2);
    final sinLng = math.sin(deltaLng / 2);
    final value =
        sinLat * sinLat + math.cos(lat1) * math.cos(lat2) * sinLng * sinLng;
    return earthRadiusMeters *
        2 *
        math.atan2(math.sqrt(value), math.sqrt(1 - value));
  }

  double _radians(double degrees) => degrees * math.pi / 180;

  bool _isFiniteLatLng(LatLng value) {
    return value.latitude.isFinite && value.longitude.isFinite;
  }

  bool _isFiniteBounds(LatLngBounds bounds) {
    return bounds.north.isFinite &&
        bounds.south.isFinite &&
        bounds.east.isFinite &&
        bounds.west.isFinite;
  }

  MapBounds _boundsFromCamera(MapCamera camera) {
    final bounds = camera.visibleBounds;
    return MapBounds(
      north: bounds.north,
      south: bounds.south,
      east: bounds.east,
      west: bounds.west,
    );
  }

  CircleMarker _circleForLocation(StressLocation location) {
    final color = stressColorForScore(location.stressScore);
    return CircleMarker(
      point: LatLng(location.latitude, location.longitude),
      radius: 420 + location.stressScore * 18,
      useRadiusInMeter: true,
      color: color.withValues(alpha: 0.22),
      borderColor: color.withValues(alpha: 0.42),
      borderStrokeWidth: 1.5,
    );
  }

  Marker _markerForLocation(
    BuildContext context,
    StressLocation location,
    bool isSelected,
    bool isWide,
  ) {
    final color = stressColorForScore(location.stressScore);
    final markerSize = isWide ? 58.0 : 50.0;

    return Marker(
      width: markerSize,
      height: markerSize,
      point: LatLng(location.latitude, location.longitude),
      child: GestureDetector(
        onTap: () => _openLocationDetails(context, location),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: isSelected ? 0.96 : 0.82),
            border: Border.all(
              color: Colors.white.withValues(alpha: isSelected ? 0.95 : 0.34),
              width: isSelected ? 3 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: isSelected ? 24 : 16,
                spreadRadius: isSelected ? 4 : 1,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            location.stressScore.round().toString(),
            style: TextStyle(
              color: const Color(0xFF061014),
              fontWeight: FontWeight.w900,
              fontSize: isWide ? 16 : 14,
            ),
          ),
        ),
      ),
    );
  }

  Marker _currentLocationMarker(LatLng point) {
    return Marker(
      width: 34,
      height: 34,
      point: point,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF58A6FF).withValues(alpha: 0.24),
          border: Border.all(
            color: const Color(0xFF9ED0FF).withValues(alpha: 0.90),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF58A6FF).withValues(alpha: 0.45),
              blurRadius: 18,
              spreadRadius: 3,
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.navigation_rounded,
            color: Color(0xFFE8F4FF),
            size: 16,
          ),
        ),
      ),
    );
  }

  Future<void> _focusCurrentLocation() async {
    final controller = context.read<StressMapController>();
    final location = await controller.locateUser();
    if (!mounted) return;

    if (location == null) {
      final message = controller.locationMessage;
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    _mapController.move(location, 11.2);
    await controller.loadForViewport(
      center: location,
      zoom: 11.2,
      bounds: _boundsAround(location, 0.18),
    );
  }

  MapBounds _boundsAround(LatLng center, double radiusDegrees) {
    return MapBounds(
      north: (center.latitude + radiusDegrees).clamp(-85.0, 85.0),
      south: (center.latitude - radiusDegrees).clamp(-85.0, 85.0),
      east: (center.longitude + radiusDegrees).clamp(-180.0, 180.0),
      west: (center.longitude - radiusDegrees).clamp(-180.0, 180.0),
    );
  }

  void _openLocationDetails(BuildContext context, StressLocation location) {
    final controller = context.read<StressMapController>();
    controller.selectLocation(location);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF0D131D),
      constraints: const BoxConstraints(maxWidth: 520),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: height * 0.72),
              child: SingleChildScrollView(
                child: LocationDetailCard(location: location),
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) {
        controller.clearSelection();
      }
    });
  }
}

class _WideOverlay extends StatelessWidget {
  const _WideOverlay({
    required this.isLoading,
    required this.mapController,
    required this.onLocate,
    required this.isLocating,
  });

  final bool isLoading;
  final MapController mapController;
  final VoidCallback onLocate;
  final bool isLocating;

  @override
  Widget build(BuildContext context) {
    final filters = context.watch<StressMapController>().filters;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderCard(isLoading: isLoading),
              const Spacer(),
              _FilterStatusColumn(filters: filters),
              const SizedBox(height: 10),
              const LegendCard(),
            ],
          ),
        ),
        const Spacer(),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MapControls(mapController: mapController),
                  _LocateButton(
                    onPressed: onLocate,
                    isLocating: isLocating,
                    isExtended: true,
                  ),
                  const _SettingsButton(),
                  _FilterButton(isExtended: true),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileOverlay extends StatelessWidget {
  const _MobileOverlay({
    required this.isLoading,
    required this.mapController,
    required this.onLocate,
    required this.isLocating,
  });

  final bool isLoading;
  final MapController mapController;
  final VoidCallback onLocate;
  final bool isLocating;

  @override
  Widget build(BuildContext context) {
    final filters = context.watch<StressMapController>().filters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _HeaderCard(isLoading: isLoading)),
            const SizedBox(width: 10),
            const _SettingsButton(),
            const SizedBox(width: 10),
            _FilterButton(isExtended: false),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapControls(mapController: mapController),
              const SizedBox(width: 10),
              _LocateButton(
                onPressed: onLocate,
                isLocating: isLocating,
                isExtended: false,
              ),
            ],
          ),
        ),
        const Spacer(),
        _FilterStatusColumn(filters: filters, compact: true),
        const SizedBox(height: 8),
        const LegendCard(compact: true),
      ],
    );
  }
}

class _FilterStatusColumn extends StatelessWidget {
  const _FilterStatusColumn({
    required this.filters,
    this.compact = false,
  });

  final IndicatorFilters filters;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 26.0 : 28.0;

    return Container(
      padding: EdgeInsets.all(compact ? 8 : 9),
      decoration: BoxDecoration(
        color: const Color(0xE60B111A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FilterStatusIcon(
            icon: Icons.air_rounded,
            tooltip: context.tr('filters.airQuality'),
            enabled: filters.airQuality,
            size: size,
          ),
          _FilterStatusIcon(
            icon: Icons.location_city_rounded,
            tooltip: context.tr('filters.populationDensity'),
            enabled: filters.populationDensity,
            size: size,
          ),
          _FilterStatusIcon(
            icon: Icons.graphic_eq_rounded,
            tooltip: context.tr('filters.noise'),
            enabled: filters.noise,
            size: size,
          ),
          _FilterStatusIcon(
            icon: Icons.traffic_rounded,
            tooltip: context.tr('filters.traffic'),
            enabled: filters.traffic,
            size: size,
          ),
          _FilterStatusIcon(
            icon: Icons.payments_rounded,
            tooltip: context.tr('filters.costOfLiving'),
            enabled: filters.costOfLiving,
            size: size,
          ),
          _FilterStatusIcon(
            icon: Icons.shield_rounded,
            tooltip: context.tr('filters.safety'),
            enabled: filters.safety,
            size: size,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _FilterStatusIcon extends StatelessWidget {
  const _FilterStatusIcon({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.size,
    this.isLast = false,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final double size;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final iconColor = enabled
        ? const Color(0xFF35D07F)
        : const Color(0xFFFF7D8A).withValues(alpha: 0.95);
    final backgroundColor = enabled
        ? const Color(0xFF35D07F).withValues(alpha: 0.16)
        : const Color(0xFFFF4D5E).withValues(alpha: 0.18);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: iconColor.withValues(alpha: 0.42)),
          ),
          child: Icon(icon, size: size * 0.62, color: iconColor),
        ),
      ),
    );
  }
}

class _LocateButton extends StatelessWidget {
  const _LocateButton({
    required this.onPressed,
    required this.isLocating,
    required this.isExtended,
  });

  final VoidCallback onPressed;
  final bool isLocating;
  final bool isExtended;

  @override
  Widget build(BuildContext context) {
    final child = isLocating
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.my_location_rounded);

    if (isExtended) {
      return FloatingActionButton.extended(
        heroTag: 'locate',
        tooltip: 'actions.currentLocation'.tr(),
        backgroundColor: const Color(0xFF151F2D),
        foregroundColor: Colors.white,
        onPressed: isLocating ? null : onPressed,
        icon: child,
        label: Text('actions.locate'.tr()),
      );
    }

    return FloatingActionButton.small(
      heroTag: 'locate',
      tooltip: 'actions.currentLocation'.tr(),
      backgroundColor: const Color(0xFF151F2D),
      foregroundColor: Colors.white,
      onPressed: isLocating ? null : onPressed,
      child: child,
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.isExtended});

  final bool isExtended;

  @override
  Widget build(BuildContext context) {
    if (isExtended) {
      return FloatingActionButton.extended(
        heroTag: 'filters',
        tooltip: 'actions.filters'.tr(),
        backgroundColor: const Color(0xFF151F2D),
        foregroundColor: Colors.white,
        onPressed: () => _showFilters(context),
        icon: const Icon(Icons.tune_rounded),
        label: Text('actions.filters'.tr()),
      );
    }

    return FloatingActionButton.small(
      heroTag: 'filters',
      tooltip: 'actions.filters'.tr(),
      backgroundColor: const Color(0xFF151F2D),
      foregroundColor: Colors.white,
      onPressed: () => _showFilters(context),
      child: const Icon(Icons.tune_rounded),
    );
  }

  Future<void> _showFilters(BuildContext context) async {
    final controller = context.read<StressMapController>();
    final initialFilters = controller.filters;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF0D131D),
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(18),
        ),
      ),
      builder: (_) => const FilterSheet(),
    );

    if (_filtersEqual(initialFilters, controller.filters)) {
      return;
    }

    await controller.refetchCurrentViewport(forceRefresh: true);
  }

  bool _filtersEqual(IndicatorFilters a, IndicatorFilters b) {
    return a.airQuality == b.airQuality &&
        a.populationDensity == b.populationDensity &&
        a.noise == b.noise &&
        a.traffic == b.traffic &&
        a.costOfLiving == b.costOfLiving &&
        a.safety == b.safety;
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'settings',
      tooltip: 'actions.settings'.tr(),
      backgroundColor: const Color(0xFF151F2D),
      foregroundColor: Colors.white,
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: const Color(0xFF0D131D),
        constraints: const BoxConstraints(maxWidth: 560),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(18),
          ),
        ),
        builder: (_) => const SettingsSheet(),
      ),
      child: const Icon(Icons.settings_rounded),
    );
  }
}

class _MapControls extends StatelessWidget {
  const _MapControls({required this.mapController});

  final MapController mapController;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE60B111A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MapControlButton(
            icon: Icons.add_rounded,
            label: 'actions.zoomIn'.tr(),
            onPressed: () {
              final camera = mapController.camera;
              mapController.move(camera.center, camera.zoom + 1);
            },
          ),
          Container(
            width: 1,
            height: 28,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          _MapControlButton(
            icon: Icons.remove_rounded,
            label: 'actions.zoomOut'.tr(),
            onPressed: () {
              final camera = mapController.camera;
              mapController.move(camera.center, camera.zoom - 1);
            },
          ),
          Container(
            width: 1,
            height: 28,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          _MapControlButton(
            icon: Icons.public_rounded,
            label: 'actions.worldView'.tr(),
            onPressed: () {
              mapController.move(_StressMapScreenState._initialCenter, 2.5);
            },
          ),
        ],
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: SizedBox.square(
        dimension: 42,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 21),
          color: Colors.white,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 42, height: 42),
        ),
      ),
    );
  }
}

class _AttributionIconButton extends StatelessWidget {
  const _AttributionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 28,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        color: Colors.white,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _AttributionInfoButton extends StatelessWidget {
  const _AttributionInfoButton();

  @override
  Widget build(BuildContext context) {
    return _AttributionIconButton(
      icon: Icons.info_outline_rounded,
      tooltip: context.tr('actions.attributions'),
      onPressed: () => _showAttributions(context),
    );
  }

  void _showAttributions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF0D131D),
      constraints: const BoxConstraints(maxWidth: 520),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sheetContext.tr('actions.attributions'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('OpenStreetMap contributors'),
                const SizedBox(height: 4),
                const Text('CARTO basemaps'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ZoomInHintChip extends StatelessWidget {
  const _ZoomInHintChip();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xED0B111A),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF35D07F).withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.zoom_in_rounded,
              size: 18,
              color: Color(0xFF35D07F),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                context.tr('hints.zoomInToLoadData'),
                style: const TextStyle(
                  color: Color(0xFFE3ECF6),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xE60B111A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLoading
              ? const Color(0xFF35D07F).withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.09),
        ),
        boxShadow: isLoading
            ? [
                BoxShadow(
                  color: const Color(0xFF35D07F).withValues(alpha: 0.10),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF35D07F).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(
                    'web/icons/Icon-192.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'STRESSMAP',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: isLoading
                          ? Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                context.tr('loading.refreshingMapData'),
                                key: const ValueKey('loading-status'),
                                style: const TextStyle(
                                  color: Color(0xFF9ED8B7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('loading-empty'),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: isLoading
                ? Padding(
                    key: const ValueKey('loading-bar'),
                    padding: const EdgeInsets.only(top: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: const LinearProgressIndicator(
                        minHeight: 5,
                        backgroundColor: Color(0x332E3C4F),
                        color: Color(0xFF35D07F),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('loading-bar-empty')),
          ),
        ],
      ),
    );
  }
}
