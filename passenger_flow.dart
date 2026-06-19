import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../app/wow_theme.dart';
import '../../services/wow_firebase_service.dart';
import '../auth/login_placeholder_screen.dart';
import 'assignment_records.dart';
import 'models/passenger_models.dart';
import 'services/google_maps_service.dart';
import 'services/passenger_repository.dart';

const _karachi = LatLng(24.8607, 67.0011);

const vehicleOptions = [
  VehicleOption(
    id: 'wow_car',
    label: 'Car Ride',
    description: 'Comfortable car for daily trips',
    multiplier: 1,
    icon: 'car',
  ),
  VehicleOption(
    id: 'wow_bike',
    label: 'Bike Ride',
    description: 'Fast solo pickup',
    multiplier: 0.42,
    icon: 'bike',
  ),
  VehicleOption(
    id: 'wow_scooty',
    label: 'Scooty Ride',
    description: 'Easy city commute',
    multiplier: 0.55,
    icon: 'scooty',
  ),
];

class PassengerShell extends StatefulWidget {
  const PassengerShell({required this.profile, super.key});

  static const routeName = '/passenger';

  final WowUserProfile profile;

  @override
  State<PassengerShell> createState() => _PassengerShellState();
}

class _PassengerShellState extends State<PassengerShell> {
  final _repo = PassengerRepository();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_repo.saveMessagingToken());
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      PassengerHomeScreen(
        profile: widget.profile,
        onProfileTap: () => setState(() => _index = 3),
      ),
      RecordsScreen(profile: widget.profile),
      const MyRequestsScreen(),
      ProfileScreen(profile: widget.profile),
    ];

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(index: _index, children: pages),
          ),
          if (_index != 0)
            Align(
              alignment: Alignment.bottomCenter,
              child: _WebsiteBottomNav(
                selectedIndex: _index,
                onSelected: (value) => setState(() => _index = value),
              ),
            ),
        ],
      ),
    );
  }
}

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({
    required this.profile,
    required this.onProfileTap,
    super.key,
  });

  final WowUserProfile profile;
  final VoidCallback onProfileTap;

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  final _repo = PassengerRepository();
  final _maps = GoogleMapsService();
  GoogleMapController? _controller;
  StreamSubscription<Position>? _positionSubscription;
  WowPlace? _pickup;
  WowPlace? _dropoff;
  bool _locating = true;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    unawaited(_useCurrentLocation());
  }

  @override
  void dispose() {
    unawaited(_positionSubscription?.cancel());
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final permission = await _locationPermission();
      if (!permission) {
        throw Exception('Location permission is needed to pick you up.');
      }
      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      final address = await _maps.reverseGeocode(latLng);
      setState(() {
        _pickup = WowPlace(
          title: 'Current location',
          subtitle: address,
          placeId: 'current-location',
          position: latLng,
        );
      });
      await _controller?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      _listenToLocationUpdates();
    } catch (error) {
      setState(() {
        _pickup = const WowPlace(
          title: 'Karachi',
          subtitle: 'Pakistan',
          placeId: 'karachi-fallback',
          position: _karachi,
        );
        _locationError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _locating = false);
      }
    }
  }

  Future<bool> _locationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  void _listenToLocationUpdates() {
    unawaited(_positionSubscription?.cancel());
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 12,
    );
    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen((
          position,
        ) {
          if (!mounted) {
            return;
          }
          final latLng = LatLng(position.latitude, position.longitude);
          setState(() {
            _pickup = WowPlace(
              title: 'Current location',
              subtitle: _pickup?.subtitle ?? 'Live location',
              placeId: 'current-location',
              position: latLng,
            );
          });
        });
  }

  Future<void> _pickLocation(bool isPickup) async {
    final result = await Navigator.of(context).push<WowPlace>(
      MaterialPageRoute(
        builder: (_) => SearchLocationScreen(
          title: isPickup ? 'Pickup location' : 'Where to?',
        ),
      ),
    );
    if (result == null) {
      return;
    }
    setState(() {
      if (isPickup) {
        _pickup = result;
      } else {
        _dropoff = result;
      }
    });
    final target = result.position;
    if (target != null) {
      await _controller?.animateCamera(CameraUpdate.newLatLngZoom(target, 14));
    }
  }

  Future<void> _continueBooking() async {
    final pickup = _pickup;
    final dropoff = _dropoff;
    if (pickup?.position == null || dropoff?.position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose pickup and destination first.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RideBookingScreen(pickup: pickup!, dropoff: dropoff!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final camera = CameraPosition(
      target: _pickup?.position ?? _karachi,
      zoom: 13,
    );
    return StreamBuilder<WowRide?>(
      stream: _repo.activeRide(),
      builder: (context, snapshot) {
        final activeRide = snapshot.data;
        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: camera,
                  myLocationButtonEnabled: false,
                  myLocationEnabled: true,
                  zoomControlsEnabled: false,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                  onMapCreated: (controller) => _controller = controller,
                  markers: {
                    if (_pickup?.position != null)
                      Marker(
                        markerId: const MarkerId('pickup'),
                        position: _pickup!.position!,
                        infoWindow: InfoWindow(title: _pickup!.title),
                      ),
                    if (_dropoff?.position != null)
                      Marker(
                        markerId: const MarkerId('dropoff'),
                        position: _dropoff!.position!,
                        infoWindow: InfoWindow(title: _dropoff!.title),
                      ),
                  },
                ),
              ),
              Positioned(
                left: 16,
                top: MediaQuery.paddingOf(context).top + 14,
                child: _MapMenuButton(onTap: widget.onProfileTap),
              ),
              Positioned(
                right: 16,
                bottom: 360,
                child: _RoundIconButton(
                  icon: Icons.my_location_rounded,
                  onPressed: _useCurrentLocation,
                ),
              ),
              if (_pickup != null)
                Positioned(
                  top: MediaQuery.sizeOf(context).height * 0.28,
                  left: 0,
                  right: 0,
                  child: _PickupMapCallout(
                    title: _locating ? 'Where from' : _pickup!.title,
                    subtitle: _pickup!.subtitle,
                    onTap: () => _pickLocation(true),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _HomeBookingSheet(
                  name: widget.profile.name,
                  pickup: _pickup,
                  dropoff: _dropoff,
                  activeRide: activeRide,
                  locating: _locating,
                  locationError: _locationError,
                  onPickup: () => _pickLocation(true),
                  onDropoff: () => _pickLocation(false),
                  onBook: _continueBooking,
                  onActiveRide: activeRide == null
                      ? null
                      : () => _openRideStatus(context, activeRide),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SearchLocationScreen extends StatefulWidget {
  const SearchLocationScreen({required this.title, super.key});

  final String title;

  @override
  State<SearchLocationScreen> createState() => _SearchLocationScreenState();
}

class _SearchLocationScreenState extends State<SearchLocationScreen> {
  final _controller = TextEditingController();
  final _maps = GoogleMapsService();
  Timer? _debounce;
  List<WowPlace> _places = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final places = await _maps.autocomplete(value);
        if (mounted) {
          setState(() => _places = places);
        }
      } catch (_) {
        if (mounted) {
          setState(() => _error = 'Location search failed. Try again.');
        }
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    });
  }

  Future<void> _select(WowPlace place) async {
    setState(() => _loading = true);
    try {
      final details = await _maps.placeDetails(place);
      if (mounted) {
        Navigator.of(context).pop(details);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load this location.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _WowPageBackground(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          _TopPanel(
            title: widget.title,
            subtitle: 'Search Karachi locations',
            onBack: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'Search area, road, building',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: WowColors.danger)),
          ],
          const SizedBox(height: 10),
          for (final place in _places)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: WowColors.line,
                child: Icon(Icons.location_on_rounded, color: WowColors.purple),
              ),
              title: Text(
                place.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(place.subtitle),
              onTap: () => _select(place),
            ),
        ],
      ),
    );
  }
}

class RideBookingScreen extends StatefulWidget {
  const RideBookingScreen({
    required this.pickup,
    required this.dropoff,
    super.key,
  });

  final WowPlace pickup;
  final WowPlace dropoff;

  @override
  State<RideBookingScreen> createState() => _RideBookingScreenState();
}

class _RideBookingScreenState extends State<RideBookingScreen> {
  final _maps = GoogleMapsService();
  final _repo = PassengerRepository();
  var _vehicle = vehicleOptions.first;
  var _paymentMethod = 'Cash';
  RideEstimate? _estimate;
  List<LatLng> _route = const [];
  bool _loading = true;
  bool _booking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadEstimate());
  }

  Future<void> _loadEstimate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pickup = widget.pickup.position!;
      final dropoff = widget.dropoff.position!;
      final results = await Future.wait([
        _maps.estimate(
          pickup: pickup,
          dropoff: dropoff,
          multiplier: _vehicle.multiplier,
        ),
        _maps.routePolyline(pickup: pickup, dropoff: dropoff),
      ]);
      setState(() {
        _estimate = results[0] as RideEstimate;
        _route = results[1] as List<LatLng>;
      });
    } catch (_) {
      setState(() => _error = 'Fare estimate is unavailable right now.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _book() async {
    final estimate = _estimate;
    if (estimate == null) {
      return;
    }
    setState(() => _booking = true);
    try {
      final rideId = await _repo.createRide(
        RideRequestDraft(
          pickup: widget.pickup,
          dropoff: widget.dropoff,
          estimate: estimate,
          vehicle: _vehicle,
          paymentMethod: _paymentMethod,
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SearchingDriverScreen(rideId: rideId),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride request failed. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _booking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickup = widget.pickup.position!;
    final dropoff = widget.dropoff.position!;
    return _WowPageBackground(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          _TopPanel(
            title: 'Book a Ride',
            subtitle: 'Choose Ride',
            onBack: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 14),
          _MapCard(
            height: 260,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: pickup, zoom: 13),
              markers: {
                Marker(markerId: const MarkerId('pickup'), position: pickup),
                Marker(markerId: const MarkerId('dropoff'), position: dropoff),
              },
              polylines: {
                if (_route.isNotEmpty)
                  Polyline(
                    polylineId: const PolylineId('route'),
                    color: WowColors.purple,
                    width: 5,
                    points: _route,
                  ),
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),
          const SizedBox(height: 14),
          _WebsiteSection(
            title: 'Choose Ride',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RouteSummary(pickup: widget.pickup, dropoff: widget.dropoff),
                const SizedBox(height: 14),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  Text(_error!, style: const TextStyle(color: WowColors.danger))
                else ...[
                  for (final option in vehicleOptions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: option.id == _vehicle.id
                                ? WowColors.purple
                                : const Color(0x299A48FF),
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: option.id == _vehicle.id
                              ? const [
                                  BoxShadow(
                                    color: Color(0x249A48FF),
                                    blurRadius: 24,
                                    offset: Offset(0, 12),
                                  ),
                                ]
                              : null,
                        ),
                        child: _VehicleTile(
                          option: option,
                          baseFare: _estimate!.fare,
                          selected: option.id == _vehicle.id,
                          onTap: () {
                            setState(() => _vehicle = option);
                            unawaited(_loadEstimate());
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  _OfferBox(
                    fare: (_estimate!.fare * _vehicle.multiplier).round(),
                  ),
                  const SizedBox(height: 12),
                  _PaymentChooser(
                    value: _paymentMethod,
                    onChanged: (value) =>
                        setState(() => _paymentMethod = value),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _booking ? null : _book,
                    child: _booking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Book ${_vehicle.label} - Rs ${_estimate!.fare}',
                          ),
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

class SearchingDriverScreen extends StatelessWidget {
  const SearchingDriverScreen({required this.rideId, super.key});

  final String rideId;

  @override
  Widget build(BuildContext context) {
    final repo = PassengerRepository();
    return StreamBuilder<List<WowRide>>(
      stream: repo.passengerRides(),
      builder: (context, snapshot) {
        final ride = snapshot.data
            ?.where((item) => item.id == rideId)
            .cast<WowRide?>()
            .firstOrNull;
        if (ride != null && ride.driverUid != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => DriverAssignedScreen(ride: ride),
                ),
              );
            }
          });
        }
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                    width: 118,
                    height: 118,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [WowColors.violet, WowColors.pink],
                      ),
                    ),
                    child: const Icon(
                      Icons.radar_rounded,
                      color: Colors.white,
                      size: 58,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Finding a nearby captain',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: WowColors.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ride == null
                        ? 'Sending your request to verified WomenOnWheels drivers.'
                        : '${ride.pickupAddress} to ${ride.dropoffAddress}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: WowColors.muted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const LinearProgressIndicator(),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: ride == null
                        ? null
                        : () async {
                            await repo.cancelRide(ride.id);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                    child: const Text('Cancel request'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class DriverAssignedScreen extends StatelessWidget {
  const DriverAssignedScreen({required this.ride, super.key});

  final WowRide ride;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Text(
                'Captain assigned',
                style: TextStyle(
                  color: WowColors.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your verified WomenOnWheels captain is heading to pickup.',
                style: TextStyle(color: WowColors.muted, height: 1.45),
              ),
              const SizedBox(height: 24),
              _DriverCard(ride: ride),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => LiveRideTrackingScreen(rideId: ride.id),
                  ),
                ),
                child: const Text('Track live ride'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SosSafetyScreen(ride: ride),
                  ),
                ),
                icon: const Icon(Icons.shield_rounded),
                label: const Text('Open safety tools'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class LiveRideTrackingScreen extends StatelessWidget {
  const LiveRideTrackingScreen({required this.rideId, super.key});

  final String rideId;

  @override
  Widget build(BuildContext context) {
    final repo = PassengerRepository();
    return StreamBuilder<List<WowRide>>(
      stream: repo.passengerRides(),
      builder: (context, snapshot) {
        final ride = snapshot.data
            ?.where((item) => item.id == rideId)
            .cast<WowRide?>()
            .firstOrNull;
        if (ride == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final pickup = ride.pickupLatLng ?? _karachi;
        final dropoff = ride.dropoffLatLng ?? pickup;
        final driver = ride.driverLatLng;
        if (ride.status == 'completed') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => RideCompletedScreen(ride: ride),
                ),
              );
            }
          });
        }
        return Scaffold(
          body: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: driver ?? pickup,
                  zoom: 14,
                ),
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                markers: {
                  Marker(markerId: const MarkerId('pickup'), position: pickup),
                  Marker(
                    markerId: const MarkerId('dropoff'),
                    position: dropoff,
                  ),
                  if (driver != null)
                    Marker(
                      markerId: const MarkerId('driver'),
                      position: driver,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRose,
                      ),
                    ),
                },
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _Panel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StatusPill(status: ride.status),
                      const SizedBox(height: 14),
                      _DriverCard(ride: ride),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SosSafetyScreen(ride: ride),
                                ),
                              ),
                              icon: const Icon(Icons.sos_rounded),
                              label: const Text('SOS'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PaymentScreen(ride: ride),
                                ),
                              ),
                              icon: const Icon(Icons.payments_rounded),
                              label: const Text('Payment'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({required this.ride, super.key});

  final WowRide ride;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _repo = PassengerRepository();
  late String _method;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _method = widget.ride.paymentMethod;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _repo.updatePaymentMethod(widget.ride.id, _method);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment method updated.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _ReceiptBox(ride: widget.ride),
          const SizedBox(height: 18),
          _PaymentChooser(
            value: _method,
            onChanged: (value) => setState(() => _method = value),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Confirm payment'),
          ),
        ],
      ),
    );
  }
}

class RideCompletedScreen extends StatefulWidget {
  const RideCompletedScreen({required this.ride, super.key});

  final WowRide ride;

  @override
  State<RideCompletedScreen> createState() => _RideCompletedScreenState();
}

class _RideCompletedScreenState extends State<RideCompletedScreen> {
  final _repo = PassengerRepository();
  final _note = TextEditingController();
  int _rating = 5;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    await _repo.completeRide(widget.ride.id, _rating, _note.text);
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ride complete')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _ReceiptBox(ride: widget.ride),
          const SizedBox(height: 22),
          const Text(
            'Rate your captain',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (index) {
              final value = index + 1;
              return IconButton(
                onPressed: () => setState(() => _rating = value),
                icon: Icon(
                  value <= _rating
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: WowColors.warning,
                  size: 34,
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Add a note'),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _saving ? null : _finish,
            child: Text(_saving ? 'Saving...' : 'Done'),
          ),
        ],
      ),
    );
  }
}

class RideHistoryScreen extends StatelessWidget {
  const RideHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = PassengerRepository();
    return _WowPageBackground(
      child: StreamBuilder<List<WowRide>>(
        stream: repo.passengerRides(),
        builder: (context, snapshot) {
          final rides = snapshot.data ?? const <WowRide>[];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (rides.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 124),
              children: const [
                _TopPanelStatic(
                  title: 'Ride history',
                  subtitle: 'Recent Rides',
                ),
                SizedBox(height: 14),
                _EmptyState(
                  icon: Icons.route_rounded,
                  title: 'No trips yet',
                  body: 'Your WomenOnWheels rides will appear here.',
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 124),
            itemBuilder: (_, index) => index == 0
                ? const _TopPanelStatic(
                    title: 'Ride history',
                    subtitle: 'Recent Rides',
                  )
                : _RideHistoryTile(ride: rides[index - 1]),
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemCount: rides.length + 1,
          );
        },
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = PassengerRepository();
    return _WowPageBackground(
      child: StreamBuilder<List<WowRide>>(
        stream: repo.passengerRides(),
        builder: (context, snapshot) {
          final rides = snapshot.data ?? const <WowRide>[];
          final active = rides
              .where((ride) => ride.status != 'completed')
              .toList();
          if (active.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 124),
              children: const [
                _TopPanelStatic(
                  title: 'Notifications',
                  subtitle: 'Ride updates and alerts',
                ),
                SizedBox(height: 14),
                _EmptyState(
                  icon: Icons.notifications_active_outlined,
                  title: 'No active alerts',
                  body: 'Ride status updates and safety alerts will land here.',
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 124),
            children: [
              const _TopPanelStatic(
                title: 'Notifications',
                subtitle: 'Ride updates and alerts',
              ),
              const SizedBox(height: 14),
              for (final ride in active)
                _InfoCard(
                  icon: Icons.local_taxi_rounded,
                  title: ride.rideCode,
                  body: 'Status: ${ride.status} - ${ride.dropoffAddress}',
                ),
            ],
          );
        },
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.profile, super.key});

  final WowUserProfile profile;

  @override
  Widget build(BuildContext context) {
    final service = WowFirebaseService();
    final photoUrl = (profile.data['photoURL'] ?? '').toString();
    final phone = (profile.data['phoneNumber'] ?? profile.data['phone'] ?? '')
        .toString();
    final provider = (profile.data['authProvider'] ?? 'Firebase').toString();
    return _WowPageBackground(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 124),
        children: [
          const _TopPanelStatic(
            title: 'Profile',
            subtitle: 'Passenger account',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: WowColors.purple,
                backgroundImage: photoUrl.isEmpty
                    ? null
                    : NetworkImage(photoUrl),
                child: photoUrl.isNotEmpty
                    ? null
                    : Text(
                        profile.name.trim().isEmpty
                            ? 'W'
                            : profile.name.trim()[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      profile.email,
                      style: const TextStyle(color: WowColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _InfoCard(
            icon: Icons.phone_rounded,
            title: 'Phone',
            body: phone.isEmpty ? 'Not added' : phone,
          ),
          _InfoCard(
            icon: Icons.login_rounded,
            title: 'Auth provider',
            body: provider,
          ),
          _InfoCard(
            icon: Icons.verified_user_rounded,
            title: 'Account',
            body: (profile.data['isActive'] == false)
                ? 'Inactive'
                : 'Active passenger',
          ),
          _InfoCard(
            icon: Icons.lock_rounded,
            title: 'Safety profile',
            body: 'SOS and live ride tracking are enabled for ride requests.',
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () async {
              await service.signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  LoginPlaceholderScreen.routeName,
                  (_) => false,
                );
              }
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class SosSafetyScreen extends StatefulWidget {
  const SosSafetyScreen({required this.ride, super.key});

  final WowRide ride;

  @override
  State<SosSafetyScreen> createState() => _SosSafetyScreenState();
}

class _SosSafetyScreenState extends State<SosSafetyScreen> {
  final _repo = PassengerRepository();
  bool _triggered = false;

  Future<void> _trigger() async {
    await _repo.triggerSos(widget.ride.id);
    if (mounted) {
      setState(() => _triggered = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SOS alert sent with your ride details.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2F6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFCBDC)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.shield_rounded,
                  color: WowColors.pink,
                  size: 52,
                ),
                const SizedBox(height: 12),
                const Text(
                  'WomenOnWheels Safety',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.ride.rideCode,
                  style: const TextStyle(
                    color: WowColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _InfoCard(
            icon: Icons.share_location_rounded,
            title: 'Live trip',
            body:
                '${widget.ride.pickupAddress} to ${widget.ride.dropoffAddress}',
          ),
          _InfoCard(
            icon: Icons.person_pin_circle_rounded,
            title: 'Captain',
            body: widget.ride.driverName,
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _triggered ? null : _trigger,
            icon: const Icon(Icons.sos_rounded),
            label: Text(_triggered ? 'SOS sent' : 'Send SOS alert'),
            style: ElevatedButton.styleFrom(backgroundColor: WowColors.danger),
          ),
        ],
      ),
    );
  }
}

void _openRideStatus(BuildContext context, WowRide ride) {
  if (ride.driverUid == null) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SearchingDriverScreen(rideId: ride.id)),
    );
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => LiveRideTrackingScreen(rideId: ride.id)),
  );
}

class _WowPageBackground extends StatelessWidget {
  const _WowPageBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF8FE), Color(0xFFF7F1FB), Color(0xFFF2EBFA)],
            stops: [0, 0.48, 1],
          ),
        ),
        child: SafeArea(child: child),
      ),
    );
  }
}

class _WebsiteBottomNav extends StatelessWidget {
  const _WebsiteBottomNav({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.folder_copy_rounded, 'Records'),
    (Icons.receipt_long_rounded, 'Requests'),
    (Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(5, 0, 5, 14),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          border: Border.all(color: const Color(0x1F9A48FF)),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x242D1446),
              blurRadius: 34,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            final active = index == selectedIndex;
            return Expanded(
              child: InkWell(
                onTap: () => onSelected(index),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: active
                        ? const LinearGradient(
                            colors: [WowColors.purple, WowColors.pink],
                          )
                        : null,
                    boxShadow: active
                        ? const [
                            BoxShadow(
                              color: Color(0x339A48FF),
                              blurRadius: 16,
                              offset: Offset(0, 10),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.$1,
                        size: 18,
                        color: active ? Colors.white : WowColors.muted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.$2,
                        style: TextStyle(
                          color: active ? Colors.white : WowColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _TopPanel extends StatelessWidget {
  const _TopPanel({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _gradientPanelDecoration(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _BackPill(onPressed: onBack),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopPanelStatic extends StatelessWidget {
  const _TopPanelStatic({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _gradientPanelDecoration(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackPill extends StatelessWidget {
  const _BackPill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back_rounded, size: 14),
      label: const Text('Back'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white.withValues(alpha: 0.14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        minimumSize: const Size(72, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _WebsiteSection extends StatelessWidget {
  const _WebsiteSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: WowColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration(22).copyWith(color: const Color(0xFFE7E0EF)),
      child: child,
    );
  }
}

class _MapMenuButton extends StatelessWidget {
  const _MapMenuButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF7FFFFFF),
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: const Color(0x3328153B),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const SizedBox(
              width: 58,
              height: 58,
              child: Icon(Icons.menu_rounded, color: WowColors.ink, size: 30),
            ),
            Positioned(
              right: 3,
              top: -1,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: WowColors.pink,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickupMapCallout extends StatelessWidget {
  const _PickupMapCallout({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 236, minHeight: 78),
              padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
              decoration: BoxDecoration(
                color: const Color(0xF7FFFFFF),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3328153B),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Where from',
                          style: TextStyle(
                            color: WowColors.muted.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: WowColors.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: WowColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.chevron_right_rounded, color: WowColors.ink),
                ],
              ),
            ),
          ),
          Container(
            width: 3,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
              boxShadow: const [
                BoxShadow(color: Color(0x3328153B), blurRadius: 8),
              ],
            ),
          ),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3328153B),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.person_pin_circle_rounded,
              color: WowColors.purple,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _gradientPanelDecoration(double radius) {
  return BoxDecoration(
    gradient: const LinearGradient(
      colors: [WowColors.purple, WowColors.pink],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: const [
      BoxShadow(
        color: Color(0x1F7035B2),
        blurRadius: 40,
        offset: Offset(0, 18),
      ),
    ],
  );
}

BoxDecoration _cardDecoration(double radius) {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.9),
    border: Border.all(color: const Color(0x249A48FF)),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: const [
      BoxShadow(
        color: Color(0x14472164),
        blurRadius: 30,
        offset: Offset(0, 12),
      ),
    ],
  );
}

class _HomeBookingSheet extends StatelessWidget {
  const _HomeBookingSheet({
    required this.name,
    required this.pickup,
    required this.dropoff,
    required this.activeRide,
    required this.locating,
    required this.locationError,
    required this.onPickup,
    required this.onDropoff,
    required this.onBook,
    required this.onActiveRide,
  });

  final String name;
  final WowPlace? pickup;
  final WowPlace? dropoff;
  final WowRide? activeRide;
  final bool locating;
  final String? locationError;
  final VoidCallback onPickup;
  final VoidCallback onDropoff;
  final VoidCallback onBook;
  final VoidCallback? onActiveRide;

  @override
  Widget build(BuildContext context) {
    final recentPlaces = [
      (
        Icons.schedule_rounded,
        'Ginza Terrace',
        'Orange Street, Garden West Area, Karachi',
      ),
      (
        Icons.schedule_rounded,
        'Saima Pari Mall',
        'Shahrah-e-Sher Shah, Karachi',
      ),
    ];
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 398),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
        decoration: const BoxDecoration(
          color: Color(0xFFFDF8FF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
          boxShadow: [
            BoxShadow(
              color: Color(0x3328153B),
              blurRadius: 32,
              offset: Offset(0, -12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFD7C8E6),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              if (activeRide != null) ...[
                InkWell(
                  onTap: onActiveRide,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [WowColors.purple, WowColors.pink],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.route_rounded, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${activeRide!.rideCode} - ${activeRide!.status}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _ServiceGrid(onSelected: onDropoff),
              const SizedBox(height: 14),
              InkWell(
                onTap: onDropoff,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE8D8F5)),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: WowColors.ink),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          dropoff == null
                              ? 'Where to and for how much?'
                              : dropoff!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: WowColors.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (locationError != null) ...[
                const SizedBox(height: 8),
                Text(
                  locationError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: WowColors.danger, fontSize: 12),
                ),
              ],
              if (dropoff != null) ...[
                const SizedBox(height: 12),
                _RouteMiniSummary(
                  pickup: locating
                      ? 'Finding pickup...'
                      : pickup?.title ?? 'Pickup',
                  dropoff: dropoff!.title,
                  onPickup: onPickup,
                  onBook: onBook,
                ),
              ] else ...[
                const SizedBox(height: 14),
                for (final place in recentPlaces)
                  _RecentPlaceTile(
                    icon: place.$1,
                    title: place.$2,
                    subtitle: place.$3,
                    onTap: onDropoff,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.onSelected});

  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RideServiceCard(
            option: vehicleOptions[0],
            featured: true,
            onTap: onSelected,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              _RideServiceCard(option: vehicleOptions[1], onTap: onSelected),
              const SizedBox(height: 10),
              _RideServiceCard(option: vehicleOptions[2], onTap: onSelected),
            ],
          ),
        ),
      ],
    );
  }
}

class _RideServiceCard extends StatelessWidget {
  const _RideServiceCard({
    required this.option,
    required this.onTap,
    this.featured = false,
  });

  final VehicleOption option;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: featured ? 148 : 69,
        padding: EdgeInsets.all(featured ? 14 : 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFFFEEF8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFFE8D8F5)),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: featured ? 100 : 72,
                child: Text(
                  option.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: WowColors.ink,
                    fontSize: featured ? 18 : 15,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Positioned(
              right: featured ? -8 : -4,
              bottom: featured ? -8 : -6,
              child: _VehicleImage(option: option, size: featured ? 92 : 58),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteMiniSummary extends StatelessWidget {
  const _RouteMiniSummary({
    required this.pickup,
    required this.dropoff,
    required this.onPickup,
    required this.onBook,
  });

  final String pickup;
  final String dropoff;
  final VoidCallback onPickup;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SmallLocationPill(
                label: 'From',
                value: pickup,
                icon: Icons.radio_button_checked_rounded,
                onTap: onPickup,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SmallLocationPill(
                label: 'To',
                value: dropoff,
                icon: Icons.location_on_rounded,
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onBook,
            child: const Text('Choose Ride'),
          ),
        ),
      ],
    );
  }
}

class _SmallLocationPill extends StatelessWidget {
  const _SmallLocationPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE8D8F5)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: WowColors.pink, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: WowColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: WowColors.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentPlaceTile extends StatelessWidget {
  const _RecentPlaceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      minLeadingWidth: 30,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: WowColors.muted),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: WowColors.ink,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: WowColors.muted),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: _cardDecoration(22),
      child: SafeArea(top: false, child: child),
    );
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          border: Border.all(color: const Color(0x1F9A48FF)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: WowColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({
    required this.option,
    required this.baseFare,
    required this.selected,
    required this.onTap,
  });

  final VehicleOption option;
  final int baseFare;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      tileColor: Colors.white,
      selectedTileColor: const Color(0xFFF7EEFF),
      selected: selected,
      leading: _VehicleImage(option: option, size: 42),
      title: Text(
        option.label,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
      ),
      subtitle: Text(option.description),
      trailing: Text(
        'Rs ${(baseFare * option.multiplier).round()}',
        style: const TextStyle(
          color: WowColors.purple,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _VehicleImage extends StatelessWidget {
  const _VehicleImage({required this.option, required this.size});

  final VehicleOption option;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = switch (option.icon) {
      'bike' => 'assets/images/bike.png',
      'scooty' => 'assets/images/scooty.png',
      _ => 'assets/images/car.png',
    };
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5ECFF),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Image.asset(asset, fit: BoxFit.contain),
    );
  }
}

class _OfferBox extends StatelessWidget {
  const _OfferBox({required this.fare});

  final int fare;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F2FB),
        border: Border.all(color: const Color(0xFFD6C5EA)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Offer',
                  style: TextStyle(
                    color: WowColors.ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Adjust fare if needed',
                  style: TextStyle(color: WowColors.muted, fontSize: 9),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFB67DFF)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Rs. $fare',
              style: const TextStyle(
                color: Color(0xFF7D43E8),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentChooser extends StatelessWidget {
  const _PaymentChooser({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const methods = ['Cash', 'Card', 'EasyPaisa', 'JazzCash'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final method in methods)
          _PaymentChip(
            method: method,
            selected: value == method,
            onTap: () => onChanged(method),
          ),
      ],
    );
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final String method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (method) {
      'EasyPaisa' => 'EP',
      'JazzCash' => 'JC',
      'Card' => 'NP',
      _ => 'Rs',
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 154,
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF7FB) : Colors.white,
          border: Border.all(
            color: selected ? WowColors.purple : const Color(0xFFDFCDF3),
            width: selected ? 1.4 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x249A48FF),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        colors: [WowColors.purple, WowColors.pink],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFEFE2FF), Color(0xFFFCE7F3)],
                      ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : WowColors.purple,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    method,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF41295A),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    method == 'Cash' ? 'Pay directly' : 'Mobile wallet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: WowColors.muted, fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.pickup, required this.dropoff});

  final WowPlace pickup;
  final WowPlace dropoff;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LocationField(
          icon: Icons.radio_button_checked_rounded,
          iconColor: WowColors.success,
          title: pickup.title,
          subtitle: pickup.subtitle,
          onTap: () {},
        ),
        const SizedBox(height: 8),
        _LocationField(
          icon: Icons.location_on_rounded,
          iconColor: WowColors.pink,
          title: dropoff.title,
          subtitle: dropoff.subtitle,
          onTap: () {},
        ),
      ],
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.ride});

  final WowRide ride;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: WowColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: WowColors.purple,
            child: Icon(Icons.person_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ride.driverName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    ride.vehicleNumber,
                    ride.driverPhone,
                  ].where((item) => item.isNotEmpty).join(' - '),
                  style: const TextStyle(color: WowColors.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified_rounded, color: WowColors.success),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7EDFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, color: WowColors.purple, size: 18),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ReceiptBox extends StatelessWidget {
  const _ReceiptBox({required this.ride});

  final WowRide ride;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: WowColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ride.rideCode,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(ride.pickupAddress),
          const SizedBox(height: 6),
          Text(ride.dropoffAddress),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Fare', style: TextStyle(fontWeight: FontWeight.w800)),
              Text(
                'Rs ${ride.fare.round()}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${ride.distanceKm.toStringAsFixed(1)} km - ${ride.durationMinutes} min - ${ride.paymentMethod}',
            style: const TextStyle(color: WowColors.muted),
          ),
        ],
      ),
    );
  }
}

class _RideHistoryTile extends StatelessWidget {
  const _RideHistoryTile({required this.ride});

  final WowRide ride;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openRideStatus(context, ride),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: WowColors.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.route_rounded, color: WowColors.purple),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ride.rideCode,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ride.dropoffAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: WowColors.muted),
                  ),
                ],
              ),
            ),
            Text(
              'Rs ${ride.fare.round()}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: WowColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: WowColors.purple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(body, style: const TextStyle(color: WowColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: WowColors.purple, size: 48),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: WowColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: WowColors.ink),
      ),
    );
  }
}
