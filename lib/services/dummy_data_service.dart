import 'dart:math';
import '../models/call_log.dart';

class DummyDataService {
  static final List<String> _names = [
    'John Doe',
    'Jane Smith',
    'Mike Johnson',
    'Sarah Williams',
    'David Brown',
    'Emily Davis',
    'Robert Wilson',
    'Lisa Anderson',
    'James Taylor',
    'Mary Thomas',
  ];

  static final List<String> _phoneNumbers = [
    '+1 (555) 123-4567',
    '+1 (555) 234-5678',
    '+1 (555) 345-6789',
    '+1 (555) 456-7890',
    '+1 (555) 567-8901',
    '+1 (555) 678-9012',
    '+1 (555) 789-0123',
    '+1 (555) 890-1234',
    '+1 (555) 901-2345',
    '+1 (555) 012-3456',
  ];

  static List<CallLog> generateDummyCallLogs(int count) {
    final random = Random();
    final now = DateTime.now();
    final List<CallLog> logs = [];

    for (int i = 0; i < count; i++) {
      final index = random.nextInt(_names.length);
      final timestamp = now.subtract(Duration(
        hours: random.nextInt(24),
        minutes: random.nextInt(60),
      ));
      final duration = Duration(
        minutes: random.nextInt(60),
        seconds: random.nextInt(60),
      );
      final type = CallType.values[random.nextInt(CallType.values.length)];

      logs.add(CallLog(
        contactName: _names[index],
        phoneNumber: _phoneNumbers[index],
        timestamp: timestamp,
        duration: duration,
        type: type,
      ));
    }

    // Sort logs by timestamp (most recent first)
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return logs;
  }
} 