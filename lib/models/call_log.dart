import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum CallType {
  incoming,
  outgoing,
  missed,
}

class CallLog {
  final String contactName;
  final String phoneNumber;
  final DateTime startTime;
  final DateTime endTime;
  final CallType type;

  CallLog({
    required this.contactName,
    required this.phoneNumber,
    required this.startTime,
    required this.endTime,
    required this.type,
  });

  Duration get duration => endTime.difference(startTime);

  String get formattedStartTime {
    return DateFormat('h:mm a').format(startTime);
  }

  String get formattedEndTime {
    return DateFormat('h:mm a').format(endTime);
  }

  String get formattedDate {
    return DateFormat('MMM d, y').format(startTime);
  }

  String get formattedDuration {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
  }

  IconData get callTypeIcon {
    switch (type) {
      case CallType.incoming:
        return Icons.call_received;
      case CallType.outgoing:
        return Icons.call_made;
      case CallType.missed:
        return Icons.call_missed;
    }
  }

  Color get callTypeColor {
    switch (type) {
      case CallType.incoming:
        return Colors.green;
      case CallType.outgoing:
        return Colors.blue;
      case CallType.missed:
        return Colors.red;
    }
  }
} 