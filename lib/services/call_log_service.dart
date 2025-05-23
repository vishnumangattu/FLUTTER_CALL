import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/call_log.dart' as app;

class CallLogService {
  static Future<List<app.CallLog>> getCallLogs() async {
    // Request permissions
    final status = await Permission.phone.request();
    if (!status.isGranted) {
      throw Exception('Phone permission not granted');
    }

    final callLogs = await CallLog.get();
    return callLogs.map((log) {
      final startTime = DateTime.fromMillisecondsSinceEpoch(log.timestamp ?? 0);
      final duration = Duration(seconds: log.duration ?? 0);
      final endTime = startTime.add(duration);
      
      return app.CallLog(
        contactName: log.name ?? 'Unknown',
        phoneNumber: log.number ?? 'Unknown',
        startTime: startTime,
        endTime: endTime,
        type: _getCallType(log.callType),
      );
    }).toList();
  }

  static app.CallType _getCallType(CallType? callType) {
    switch (callType) {
      case CallType.incoming:
        return app.CallType.incoming;
      case CallType.outgoing:
        return app.CallType.outgoing;
      case CallType.missed:
        return app.CallType.missed;
      default:
        return app.CallType.missed;
    }
  }
} 