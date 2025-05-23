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
      return app.CallLog(
        contactName: log.name ?? 'Unknown',
        phoneNumber: log.number ?? 'Unknown',
        timestamp: DateTime.fromMillisecondsSinceEpoch(log.timestamp ?? 0),
        duration: Duration(seconds: log.duration ?? 0),
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