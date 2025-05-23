import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfoScreen extends StatefulWidget {
  const DeviceInfoScreen({super.key});

  @override
  State<DeviceInfoScreen> createState() => _DeviceInfoScreenState();
}

class _DeviceInfoScreenState extends State<DeviceInfoScreen> {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  Map<String, dynamic> _deviceData = {};

  @override
  void initState() {
    super.initState();
    _initPlatformState();
  }

  Future<void> _initPlatformState() async {
    try {
      final androidInfo = await _deviceInfo.androidInfo;
      setState(() {
        _deviceData = {
          'Brand': androidInfo.brand,
          'Manufacturer': androidInfo.manufacturer,
          'Model': androidInfo.model,
          'Android Version': androidInfo.version.release,
          'SDK Version': androidInfo.version.sdkInt.toString(),
          'Device ID': androidInfo.id,
          'Hardware': androidInfo.hardware,
          'Product': androidInfo.product,
          'Device': androidInfo.device,
          'Board': androidInfo.board,
          'Bootloader': androidInfo.bootloader,
          'Display': androidInfo.display,
          'Fingerprint': androidInfo.fingerprint,
          'Host': androidInfo.host,
          'Tags': androidInfo.tags,
          'Type': androidInfo.type,
          'Is Physical Device': androidInfo.isPhysicalDevice.toString(),
        };
      });
    } catch (e) {
      setState(() {
        _deviceData = {'Error': 'Failed to get device info: $e'};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Information'),
      ),
      body: _deviceData.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _deviceData.length,
              itemBuilder: (context, index) {
                final key = _deviceData.keys.elementAt(index);
                final value = _deviceData[key];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          key,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          value.toString(),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
} 