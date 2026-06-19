import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

void main() {
  // Firebase connection is intentionally not started for this demo build.
  // To connect later, call Firebase.initializeApp() before runApp().
  runApp(const AdminApp());
}

class MyApp extends AdminApp {
  const MyApp({super.key});
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFB02AF5),
      primary: const Color(0xFFC026D3),
      secondary: const Color(0xFFEC4899),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WomenonWheels Admin',
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFFFF7FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFC026D3), width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFC026D3),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        useMaterial3: true,
      ),
      home: const AdminShell(),
    );
  }
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final _repo = FakeFirebaseAdminRepository();
  int _index = 0;

  @override
  void dispose() {
    _repo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      RideServicesScreen(repository: _repo),
      RequestsManagementScreen(repository: _repo),
    ];

    return GradientScaffold(
      title: _index == 0 ? 'Ride Services' : 'Ride Requests',
      subtitle: 'WomenonWheels admin panel',
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_taxi_outlined),
            selectedIcon: Icon(Icons.local_taxi),
            label: 'Services',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Rides',
          ),
        ],
      ),
    );
  }
}

class RideServicesScreen extends StatelessWidget {
  const RideServicesScreen({super.key, required this.repository});

  final FakeFirebaseAdminRepository repository;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<List<RecordItem>>(
          stream: repository.recordsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorState(message: snapshot.error.toString());
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final records = snapshot.data ?? [];
            if (records.isEmpty) {
              return const EmptyState(
                icon: Icons.local_taxi_outlined,
                message: 'No ride services yet. Tap + to add your first one.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 92),
              itemCount: records.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final record = records[index];
                return RecordCard(
                  record: record,
                  onEdit: () => _openRecordForm(context, repository, record),
                  onDelete: () => _confirmDelete(context, repository, record),
                );
              },
            );
          },
        ),
        Positioned(
          right: 18,
          bottom: 18,
          child: FloatingActionButton.extended(
            heroTag: 'add-record',
            onPressed: () => _openRecordForm(context, repository, null),
            icon: const Icon(Icons.add),
            label: const Text('Add Service'),
          ),
        ),
      ],
    );
  }

  Future<void> _openRecordForm(
    BuildContext context,
    FakeFirebaseAdminRepository repository,
    RecordItem? record,
  ) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            AddEditRecordScreen(repository: repository, existingRecord: record),
      ),
    );

    if (!context.mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          record == null ? 'Ride service created' : 'Ride service updated',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    FakeFirebaseAdminRepository repository,
    RecordItem record,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete ride service?'),
        content: Text('This will permanently remove "${record.title}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !context.mounted) return;
    await repository.deleteRecord(record.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ride service deleted')));
  }
}

class AddEditRecordScreen extends StatefulWidget {
  const AddEditRecordScreen({
    super.key,
    required this.repository,
    this.existingRecord,
  });

  final FakeFirebaseAdminRepository repository;
  final RecordItem? existingRecord;

  @override
  State<AddEditRecordScreen> createState() => _AddEditRecordScreenState();
}

class _AddEditRecordScreenState extends State<AddEditRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  bool _saving = false;

  bool get _isEditing => widget.existingRecord != null;

  @override
  void initState() {
    super.initState();
    final record = widget.existingRecord;
    _titleController = TextEditingController(text: record?.title ?? '');
    _descriptionController = TextEditingController(
      text: record?.description ?? '',
    );
    _priceController = TextEditingController(
      text: record == null ? '' : record.price.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      title: _isEditing ? 'Edit Ride Service' : 'Add Ride Service',
      subtitle: 'Save data to Firestore ride_services collection',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminPanel(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Service title',
                        prefixIcon: Icon(Icons.local_taxi_outlined),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descriptionController,
                      minLines: 4,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Route / safety details',
                        prefixIcon: Icon(Icons.shield_outlined),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Base fare',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      validator: (value) {
                        if (_required(value) != null) return 'Required';
                        final amount = double.tryParse(value!.trim());
                        if (amount == null || amount <= 0) {
                          return 'Enter a valid amount';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  _isEditing ? 'Update Ride Service' : 'Create Ride Service',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final record = RecordInput(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      price: double.parse(_priceController.text.trim()),
    );

    if (_isEditing) {
      await widget.repository.updateRecord(widget.existingRecord!.id, record);
    } else {
      await widget.repository.createRecord(record);
    }

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, true);
  }
}

class RequestsManagementScreen extends StatefulWidget {
  const RequestsManagementScreen({super.key, required this.repository});

  final FakeFirebaseAdminRepository repository;

  @override
  State<RequestsManagementScreen> createState() =>
      _RequestsManagementScreenState();
}

class _RequestsManagementScreenState extends State<RequestsManagementScreen> {
  RequestStatus? _filter;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 58,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              FilterChip(
                label: const Text('All'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              const SizedBox(width: 8),
              for (final status in RequestStatus.values) ...[
                FilterChip(
                  label: Text(status.label),
                  selected: _filter == status,
                  onSelected: (_) => setState(() => _filter = status),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<UserRequest>>(
            stream: widget.repository.requestsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorState(message: snapshot.error.toString());
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final requests = (snapshot.data ?? [])
                  .where(
                    (request) => _filter == null || request.status == _filter,
                  )
                  .toList();

              if (requests.isEmpty) {
                return const EmptyState(
                  icon: Icons.route_outlined,
                  message: 'No matching ride requests yet.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: requests.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final request = requests[index];
                  return RequestCard(
                    request: request,
                    onStatusChanged: (status) async {
                      await widget.repository.updateRequestStatus(
                        request.id,
                        status,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ride request marked ${status.label}'),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class RecordCard extends StatelessWidget {
  const RecordCard({
    super.key,
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  final RecordItem record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: appGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.local_taxi, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(record.description),
                const SizedBox(height: 10),
                Text(
                  'Base fare Rs ${record.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Color(0xFFC026D3),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: Color(0xFFE11D48)),
          ),
        ],
      ),
    );
  }
}

class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.request,
    required this.onStatusChanged,
  });

  final UserRequest request;
  final ValueChanged<RequestStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.recordTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusChip(status: request.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            request.userName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(request.notes),
          const SizedBox(height: 14),
          DropdownButtonFormField<RequestStatus>(
            initialValue: request.status,
            decoration: const InputDecoration(
              labelText: 'Update ride status',
              prefixIcon: Icon(Icons.verified_user_outlined),
            ),
            items: RequestStatus.values
                .map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(status.label),
                  ),
                )
                .toList(),
            onChanged: (status) {
              if (status != null) onStatusChanged(status);
            },
          ),
        ],
      ),
    );
  }
}

class GradientScaffold extends StatelessWidget {
  const GradientScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    this.bottomNavigationBar,
  });

  final String title;
  final String subtitle;
  final Widget body;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: appGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFF7FC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: body,
        ),
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}

class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC026D3).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: const Color(0xFFC026D3)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFE11D48)),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      RequestStatus.pending => const Color(0xFFF59E0B),
      RequestStatus.approved => const Color(0xFF16A34A),
      RequestStatus.rejected => const Color(0xFFDC2626),
    };

    return Chip(
      label: Text(status.label),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w800),
      side: BorderSide(color: color.withValues(alpha: 0.25)),
    );
  }
}

class FakeFirebaseAdminRepository {
  FakeFirebaseAdminRepository() {
    _seed();
  }

  final _recordsController = StreamController<List<RecordItem>>.broadcast();
  final _requestsController = StreamController<List<UserRequest>>.broadcast();
  final List<RecordItem> _records = [];
  final List<UserRequest> _requests = [];

  Stream<List<RecordItem>> recordsStream() {
    Future.microtask(_emitRecords);
    return _recordsController.stream;
    // Real Firebase:
    // FirebaseFirestore.instance.collection('ride_services').snapshots()
  }

  Stream<List<UserRequest>> requestsStream() {
    Future.microtask(_emitRequests);
    return _requestsController.stream;
    // Real Firebase:
    // FirebaseFirestore.instance.collection('requests').snapshots()
  }

  Future<void> createRecord(RecordInput input) async {
    await _fakeNetworkDelay();
    _records.insert(
      0,
      RecordItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: input.title,
        description: input.description,
        price: input.price,
        createdBy: 'admin_uid',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    _emitRecords();
    // Real Firebase:
    // FirebaseFirestore.instance.collection('ride_services').add({...})
  }

  Future<void> updateRecord(String id, RecordInput input) async {
    await _fakeNetworkDelay();
    final index = _records.indexWhere((record) => record.id == id);
    if (index == -1) return;
    _records[index] = _records[index].copyWith(
      title: input.title,
      description: input.description,
      price: input.price,
      updatedAt: DateTime.now(),
    );
    _emitRecords();
    // Real Firebase:
    // FirebaseFirestore.instance.collection('ride_services').doc(id).update({...})
  }

  Future<void> deleteRecord(String id) async {
    await _fakeNetworkDelay();
    _records.removeWhere((record) => record.id == id);
    _emitRecords();
    // Real Firebase:
    // FirebaseFirestore.instance.collection('ride_services').doc(id).delete()
  }

  Future<void> updateRequestStatus(String id, RequestStatus status) async {
    await _fakeNetworkDelay();
    final index = _requests.indexWhere((request) => request.id == id);
    if (index == -1) return;
    _requests[index] = _requests[index].copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );
    _emitRequests();
    // Real Firebase:
    // FirebaseFirestore.instance.collection('requests').doc(id).update({
    //   'status': status.name,
    //   'updatedAt': FieldValue.serverTimestamp(),
    // })
  }

  void dispose() {
    _recordsController.close();
    _requestsController.close();
  }

  void _seed() {
    final now = DateTime.now();
    _records.addAll([
      RecordItem(
        id: 'record_1',
        title: 'Women Only City Ride',
        description:
            'Verified female driver, live trip tracking, and emergency contact sharing.',
        price: 350,
        createdBy: 'admin_uid',
        createdAt: now,
        updatedAt: now,
      ),
      RecordItem(
        id: 'record_2',
        title: 'Safe Campus Pickup',
        description:
            'Scheduled pickup from university gates with trusted driver assignment.',
        price: 500,
        createdBy: 'admin_uid',
        createdAt: now,
        updatedAt: now,
      ),
    ]);

    _requests.addAll([
      UserRequest(
        id: 'request_1',
        userId: 'user_101',
        userName: 'Ayesha Khan',
        recordId: 'record_1',
        recordTitle: 'Women Only City Ride',
        notes: 'Pickup from Gulberg at 6 PM, destination DHA Phase 5.',
        status: RequestStatus.pending,
        createdAt: now,
        updatedAt: now,
      ),
      UserRequest(
        id: 'request_2',
        userId: 'user_202',
        userName: 'Fatima Ali',
        recordId: 'record_2',
        recordTitle: 'Safe Campus Pickup',
        notes: 'Daily university pickup for evening classes.',
        status: RequestStatus.approved,
        createdAt: now,
        updatedAt: now,
      ),
      UserRequest(
        id: 'request_3',
        userId: 'user_303',
        userName: 'Maham Noor',
        recordId: 'record_1',
        recordTitle: 'Women Only City Ride',
        notes: 'Need a driver with child seat availability.',
        status: RequestStatus.rejected,
        createdAt: now,
        updatedAt: now,
      ),
    ]);
  }

  void _emitRecords() => _recordsController.add(List.unmodifiable(_records));

  void _emitRequests() => _requestsController.add(List.unmodifiable(_requests));

  Future<void> _fakeNetworkDelay() {
    return Future<void>.delayed(const Duration(milliseconds: 450));
  }
}

class FirestoreAdminRepository {
  FirestoreAdminRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _rideServices =>
      _firestore.collection('ride_services');

  CollectionReference<Map<String, dynamic>> get _rideRequests =>
      _firestore.collection('ride_requests');

  Stream<List<RecordItem>> recordsStream() {
    return _rideServices
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RecordItem.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<UserRequest>> requestsStream() {
    return _rideRequests
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserRequest.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> createRecord(RecordInput input) async {
    final now = FieldValue.serverTimestamp();
    await _rideServices.add({
      'title': input.title,
      'description': input.description,
      'price': input.price,
      'createdAt': now,
      'updatedAt': now,
      'createdBy': _auth.currentUser?.uid ?? 'admin_uid',
    });
  }

  Future<void> updateRecord(String id, RecordInput input) async {
    await _rideServices.doc(id).update({
      'title': input.title,
      'description': input.description,
      'price': input.price,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRecord(String id) async {
    await _rideServices.doc(id).delete();
  }

  Future<void> updateRequestStatus(String id, RequestStatus status) async {
    await _rideRequests.doc(id).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> createRideRequest({
    required String userName,
    required String recordId,
    required String recordTitle,
    required String notes,
  }) async {
    final user = _auth.currentUser;
    final doc = await _rideRequests.add({
      'userId': user?.uid ?? '',
      'userName': userName,
      'recordId': recordId,
      'recordTitle': recordTitle,
      'notes': notes,
      'status': RequestStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<List<UserRequest>> myRequestsStream(String uid) {
    return _rideRequests
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserRequest.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<String> currentUserRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'user';
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['role'] as String? ?? 'user';
  }
}

class RecordInput {
  const RecordInput({
    required this.title,
    required this.description,
    required this.price,
  });

  final String title;
  final String description;
  final double price;
}

class RecordItem {
  const RecordItem({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final double price;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory RecordItem.fromFirestore(String id, Map<String, dynamic> data) {
    return RecordItem(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  RecordItem copyWith({
    String? title,
    String? description,
    double? price,
    DateTime? updatedAt,
  }) {
    return RecordItem(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class UserRequest {
  const UserRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.recordId,
    required this.recordTitle,
    required this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String recordId;
  final String recordTitle;
  final String notes;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory UserRequest.fromFirestore(String id, Map<String, dynamic> data) {
    return UserRequest(
      id: id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      recordId: data['recordId'] as String? ?? '',
      recordTitle: data['recordTitle'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      status: RequestStatus.fromName(data['status'] as String?),
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }

  UserRequest copyWith({RequestStatus? status, DateTime? updatedAt}) {
    return UserRequest(
      id: id,
      userId: userId,
      userName: userName,
      recordId: recordId,
      recordTitle: recordTitle,
      notes: notes,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum RequestStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected');

  const RequestStatus(this.label);

  final String label;

  static RequestStatus fromName(String? value) {
    return RequestStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => RequestStatus.pending,
    );
  }
}

DateTime _dateFromFirestore(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.now();
}

const firestoreSecurityRules = r'''
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function signedIn() {
      return request.auth != null;
    }

    function isAdmin() {
      return signedIn()
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    match /users/{userId} {
      allow read: if signedIn() && (request.auth.uid == userId || isAdmin());
      allow create: if signedIn() && request.auth.uid == userId;
      allow update: if signedIn() && request.auth.uid == userId || isAdmin();
    }

    match /ride_services/{serviceId} {
      allow read: if signedIn();
      allow create, update, delete: if isAdmin();
    }

    match /ride_requests/{requestId} {
      allow create: if signedIn()
        && request.resource.data.userId == request.auth.uid
        && request.resource.data.status == 'pending';
      allow read: if isAdmin() || (signedIn() && resource.data.userId == request.auth.uid);
      allow update: if isAdmin()
        && request.resource.data.status in ['pending', 'approved', 'rejected'];
      allow delete: if isAdmin();
    }
  }
}
''';

const appGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFEC4899), Color(0xFFC026D3), Color(0xFF7C3AED)],
);
