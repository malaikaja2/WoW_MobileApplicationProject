import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/wow_firebase_service.dart';
import '../auth/login_placeholder_screen.dart';

class RoleHomeScreen extends StatelessWidget {
  const RoleHomeScreen({required this.profile, super.key});

  static const routeName = '/home';

  final WowUserProfile profile;

  @override
  Widget build(BuildContext context) {
    final service = WowFirebaseService();
    final title = switch (profile.role) {
      WowRole.admin => 'Admin Dashboard',
      WowRole.driver => 'Driver Dashboard',
      WowRole.passenger => 'Women on Wheels',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Logout',
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
          ),
        ],
      ),
      body: profile.role == WowRole.admin
          ? _AdminAppRedirect(profile: profile)
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: profile.role == WowRole.admin
                  ? null
                  : service.ridesFor(profile),
              builder: (context, snapshot) {
                final rides = snapshot.data?.docs ?? [];
                return ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    Text(
                      'Welcome, ${profile.name}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2B1C3C),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.email,
                      style: const TextStyle(color: Color(0xFF74677F)),
                    ),
                    const SizedBox(height: 18),
                    if (profile.role == WowRole.admin)
                      const _MetricTile(
                        icon: Icons.admin_panel_settings_rounded,
                        label: 'Firebase admin access is active',
                        value: 'Use the web admin panel for full controls',
                      )
                    else ...[
                      _MetricTile(
                        icon: Icons.route_rounded,
                        label: 'Synced rides',
                        value: rides.length.toString(),
                      ),
                      const SizedBox(height: 12),
                      for (final doc in rides)
                        _RideTile(id: doc.id, data: doc.data()),
                      if (rides.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 30),
                          child: Text(
                            'No rides yet. New rides created on the website will appear here in real time.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF74677F)),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _AdminAppRedirect extends StatelessWidget {
  const _AdminAppRedirect({required this.profile});

  final WowUserProfile profile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          'Welcome, ${profile.name}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2B1C3C),
          ),
        ),
        const SizedBox(height: 12),
        const _MetricTile(
          icon: Icons.admin_panel_settings_rounded,
          label: 'Admin account detected',
          value:
              'Please open the separate Women On Wheels Admin mobile app. Admin features are not available inside this user app.',
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFEFEAF2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8E44AD)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(color: Color(0xFF74677F))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RideTile extends StatelessWidget {
  const _RideTile({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text((data['rideCode'] ?? id).toString()),
        subtitle: Text('${data['pickup'] ?? ''} -> ${data['dropoff'] ?? ''}'),
        trailing: Text((data['status'] ?? 'pending').toString()),
      ),
    );
  }
}
