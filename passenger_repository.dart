import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../services/wow_firebase_service.dart';
import '../models/passenger_models.dart';

class PassengerRepository {
  PassengerRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _messaging = messaging ?? FirebaseMessaging.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;
  final FirebaseStorage _storage;

  User? get currentUser => _auth.currentUser;
  Reference get profilePhotoRoot => _storage.ref('passenger_profile_photos');

  Stream<WowUserProfile?> passengerProfile() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }
    return _firestore.collection('passengers').doc(user.uid).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) {
        return null;
      }
      final data = snapshot.data() ?? {};
      return WowUserProfile(
        uid: user.uid,
        role: WowRole.passenger,
        name: (data['name'] ?? data['fullName'] ?? user.displayName ?? 'Rider')
            .toString(),
        email: (data['email'] ?? user.email ?? '').toString(),
        data: data,
      );
    });
  }

  Stream<List<WowRide>> passengerRides() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(const []);
    }
    return _firestore
        .collection('rides')
        .where('passengerUid', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          final rides = snapshot.docs
              .map((doc) => WowRide(id: doc.id, data: doc.data()))
              .toList();
          rides.sort((a, b) {
            final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
          return rides;
        });
  }

  Stream<WowRide?> activeRide() {
    return passengerRides().map((rides) {
      for (final ride in rides) {
        if (!{'completed', 'cancelled', 'rejected'}.contains(ride.status)) {
          return ride;
        }
      }
      return null;
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> availableDrivers() {
    return _firestore
        .collection('drivers')
        .where('isOnline', isEqualTo: true)
        .where('isAvailable', isEqualTo: true)
        .snapshots();
  }

  Future<void> saveMessagingToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }
    final settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }
    final token = await _messaging.getToken();
    if (token == null) {
      return;
    }
    await _firestore.collection('passengers').doc(user.uid).set({
      'fcmToken': token,
      'fcmTokens': FieldValue.arrayUnion([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> createRide(RideRequestDraft draft) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseException(plugin: 'auth', code: 'not-authenticated');
    }
    final passenger = await _firestore
        .collection('passengers')
        .doc(user.uid)
        .get();
    final passengerData = passenger.data() ?? {};
    final rideCode = 'WOW-${100000 + Random().nextInt(899999)}';
    final ride = await _firestore.collection('rides').add({
      'rideCode': rideCode,
      'passengerUid': user.uid,
      'passengerName':
          passengerData['name'] ??
          passengerData['fullName'] ??
          user.displayName,
      'passengerPhone': passengerData['phone'],
      'passengerEmail': passengerData['email'] ?? user.email,
      'driverUid': null,
      'driverName': null,
      'driverPhone': null,
      'vehicleNumber': null,
      'vehicleType': draft.vehicle.id,
      'pickup': draft.pickup.address,
      'dropoff': draft.dropoff.address,
      'pickupAddress': draft.pickup.address,
      'dropoffAddress': draft.dropoff.address,
      'pickupLocation': {
        'lat': draft.pickup.position!.latitude,
        'lng': draft.pickup.position!.longitude,
      },
      'dropoffLocation': {
        'lat': draft.dropoff.position!.latitude,
        'lng': draft.dropoff.position!.longitude,
      },
      'distanceKm': draft.estimate.distanceKm,
      'durationMinutes': draft.estimate.durationMinutes,
      'fareEstimate': draft.estimate.fare,
      'fare': draft.estimate.fare,
      'paymentMethod': draft.paymentMethod,
      'paymentStatus': draft.paymentMethod == 'Cash'
          ? 'cash_pending'
          : 'pending',
      'status': 'requested',
      'safetyStatus': 'normal',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ride.id;
  }

  Future<void> updatePaymentMethod(String rideId, String method) {
    return _firestore.collection('rides').doc(rideId).set({
      'paymentMethod': method,
      'paymentStatus': method == 'Cash' ? 'cash_pending' : 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> completeRide(String rideId, int rating, String note) {
    return _firestore.collection('rides').doc(rideId).set({
      'status': 'completed',
      'passengerRating': rating,
      'passengerFeedback': note.trim(),
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> cancelRide(String rideId) {
    return _firestore.collection('rides').doc(rideId).set({
      'status': 'cancelled',
      'cancelledBy': 'passenger',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> triggerSos(String rideId) {
    return _firestore.collection('rides').doc(rideId).set({
      'safetyStatus': 'sos',
      'sosTriggeredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
