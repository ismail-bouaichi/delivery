import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:my_app/controllers/worker_controller.dart';

/// Driver profile — reads from GET /api/delivery-worker/me and lets the
/// driver toggle availability (PUT /api/delivery-worker/{id}/status).
class ProfilePage extends StatefulWidget {
  final int userId;

  const ProfilePage({Key? key, required this.userId}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final WorkerController _workerController = Get.find<WorkerController>();

  @override
  void initState() {
    super.initState();
    _workerController.fetchProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: Obx(() {
        final profile = _workerController.profile.value;
        if (profile == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = profile['user'] is Map ? profile['user'] : null;
        final name = user?['name'] ?? profile['name'] ?? '';
        final email = user?['email'] ?? profile['email'] ?? '';
        final phone = profile['phone'] ?? '';
        final vehicle = profile['vehicle_type'] ?? '';
        final status = _workerController.status.value;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.toString(),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    _infoRow(Icons.email, email.toString()),
                    _infoRow(Icons.phone, phone.toString()),
                    _infoRow(Icons.directions_car, vehicle.toString()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.circle,
                            size: 12,
                            color: status == WorkerStatus.available
                                ? Colors.green
                                : status == WorkerStatus.onDelivery
                                    ? Colors.blue
                                    : Colors.grey),
                        const SizedBox(width: 8),
                        Text(status.isEmpty ? 'unknown' : status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (status != WorkerStatus.onDelivery)
                      SwitchListTile(
                        title: const Text('Available for deliveries'),
                        value: status == WorkerStatus.available,
                        onChanged: (v) => _workerController.setStatus(
                            v ? WorkerStatus.available : WorkerStatus.offline),
                      )
                    else
                      const Text(
                        'You are on a delivery — status will reset when it ends.',
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _infoRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
