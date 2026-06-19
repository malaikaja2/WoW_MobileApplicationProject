import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class WowPlace {
  const WowPlace({
    required this.title,
    required this.subtitle,
    required this.placeId,
    this.position,
  });

  final String title;
  final String subtitle;
  final String placeId;
  final LatLng? position;

  String get address => subtitle.isEmpty ? title : '$title, $subtitle';
}

class RideEstimate {
  const RideEstimate({
    required this.distanceKm,
    required this.durationMinutes,
    required this.fare,
  });

  final double distanceKm;
  final int durationMinutes;
  final int fare;
}

class VehicleOption {
  const VehicleOption({
    required this.id,
    required this.label,
    required this.description,
    required this.multiplier,
    required this.icon,
  });

  final String id;
  final String label;
  final String description;
  final double multiplier;
  final String icon;
}

class RideRequestDraft {
  const RideRequestDraft({
    required this.pickup,
    required this.dropoff,
    required this.estimate,
    required this.vehicle,
    required this.paymentMethod,
  });

  final WowPlace pickup;
  final WowPlace dropoff;
  final RideEstimate estimate;
  final VehicleOption vehicle;
  final String paymentMethod;
}

class WowRide {
  const WowRide({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  String get status => (data['status'] ?? 'requested').toString();
  String get rideCode => (data['rideCode'] ?? id).toString();
  String get pickupAddress =>
      (data['pickupAddress'] ?? data['pickup'] ?? 'Pickup').toString();
  String get dropoffAddress =>
      (data['dropoffAddress'] ?? data['dropoff'] ?? 'Drop-off').toString();
  String get vehicleType => (data['vehicleType'] ?? 'wow_car').toString();
  String get paymentMethod => (data['paymentMethod'] ?? 'Cash').toString();
  String? get driverUid => data['driverUid']?.toString();
  String get driverName =>
      (data['driverName'] ?? 'Captain assigning').toString();
  String get driverPhone => (data['driverPhone'] ?? '').toString();
  String get vehicleNumber => (data['vehicleNumber'] ?? '').toString();
  double get fare => _number(data['fareEstimate'] ?? data['fare']).toDouble();
  double get distanceKm => _number(data['distanceKm']).toDouble();
  int get durationMinutes => _number(data['durationMinutes']).round();
  DateTime? get createdAt => _timestamp(data['createdAt']);

  LatLng? get pickupLatLng => _latLng(data['pickupLocation']);
  LatLng? get dropoffLatLng => _latLng(data['dropoffLocation']);
  LatLng? get driverLatLng => _latLng(data['driverLocation']);

  static num _number(Object? value) {
    if (value is num) {
      return value;
    }
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _timestamp(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }

  static LatLng? _latLng(Object? value) {
    if (value is GeoPoint) {
      return LatLng(value.latitude, value.longitude);
    }
    if (value is Map) {
      final lat = _number(value['lat'] ?? value['latitude']);
      final lng = _number(value['lng'] ?? value['longitude']);
      if (lat == 0 && lng == 0) {
        return null;
      }
      return LatLng(lat.toDouble(), lng.toDouble());
    }
    return null;
  }
}
