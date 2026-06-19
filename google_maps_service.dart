import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../config/wow_api_keys.dart';
import '../models/passenger_models.dart';

class GoogleMapsService {
  GoogleMapsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<WowPlace>> autocomplete(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return const [];
    }
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      {'input': trimmed, 'components': 'country:pk', 'key': WowApiKeys.places},
    );
    final data = await _getJson(uri);
    final predictions = data['predictions'];
    if (predictions is! List) {
      return const [];
    }
    return predictions
        .map((item) {
          final formatting = item['structured_formatting'] as Map? ?? {};
          return WowPlace(
            title: (formatting['main_text'] ?? item['description'] ?? '')
                .toString(),
            subtitle: (formatting['secondary_text'] ?? '').toString(),
            placeId: (item['place_id'] ?? '').toString(),
          );
        })
        .where((place) => place.placeId.isNotEmpty)
        .toList();
  }

  Future<WowPlace> placeDetails(WowPlace place) async {
    final uri =
        Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
          'place_id': place.placeId,
          'fields': 'geometry,formatted_address,name',
          'key': WowApiKeys.places,
        });
    final data = await _getJson(uri);
    final result = data['result'] as Map? ?? {};
    final location = ((result['geometry'] as Map?)?['location'] as Map?) ?? {};
    final lat = (location['lat'] as num?)?.toDouble();
    final lng = (location['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      throw const FormatException('Location details are unavailable.');
    }
    return WowPlace(
      title: (result['name'] ?? place.title).toString(),
      subtitle: (result['formatted_address'] ?? place.subtitle).toString(),
      placeId: place.placeId,
      position: LatLng(lat, lng),
    );
  }

  Future<RideEstimate> estimate({
    required LatLng pickup,
    required LatLng dropoff,
    required double multiplier,
  }) async {
    final uri =
        Uri.https('maps.googleapis.com', '/maps/api/distancematrix/json', {
          'origins': '${pickup.latitude},${pickup.longitude}',
          'destinations': '${dropoff.latitude},${dropoff.longitude}',
          'key': WowApiKeys.distanceMatrix,
        });
    final data = await _getJson(uri);
    final rows = data['rows'] as List? ?? [];
    final element = rows.isNotEmpty
        ? ((rows.first as Map)['elements'] as List?)?.firstOrNull as Map?
        : null;
    final distanceMeters =
        ((element?['distance'] as Map?)?['value'] as num?)?.toDouble() ?? 0;
    final durationSeconds =
        ((element?['duration'] as Map?)?['value'] as num?)?.toDouble() ?? 0;
    final distanceKm = distanceMeters / 1000;
    final durationMinutes = (durationSeconds / 60).ceil();
    final fare = (180 + (distanceKm * 75) + (durationMinutes * 8)) * multiplier;
    return RideEstimate(
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      fare: fare.clamp(220, 50000).round(),
    );
  }

  Future<List<LatLng>> routePolyline({
    required LatLng pickup,
    required LatLng dropoff,
  }) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '${pickup.latitude},${pickup.longitude}',
      'destination': '${dropoff.latitude},${dropoff.longitude}',
      'key': WowApiKeys.directions,
    });
    final data = await _getJson(uri);
    final routes = data['routes'] as List? ?? [];
    if (routes.isEmpty) {
      return const [];
    }
    final points =
        ((routes.first as Map)['overview_polyline'] as Map?)?['points'];
    if (points is! String || points.isEmpty) {
      return const [];
    }
    return _decodePolyline(points);
  }

  Future<String> reverseGeocode(LatLng position) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
      'latlng': '${position.latitude},${position.longitude}',
      'key': WowApiKeys.geocoding,
    });
    final data = await _getJson(uri);
    final results = data['results'] as List? ?? [];
    if (results.isEmpty) {
      return 'Current location';
    }
    return ((results.first as Map)['formatted_address'] ?? 'Current location')
        .toString();
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _client.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Map request failed.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status']?.toString();
    if (status != null && status != 'OK' && status != 'ZERO_RESULTS') {
      throw Exception('Map service returned $status.');
    }
    return data;
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
