import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/call_log.dart';
import 'device_info_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://172.16.99.244:5000/api/leads';
  static const String agentIdKey = 'agent_id';
  static const String syncedLogsKey = 'synced_call_logs';

  static Future<String> _getOrCreateAgentId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? agentId = prefs.getString(agentIdKey);
      
      if (agentId == null) {
        const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        final random = Random();
        agentId = List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
        await prefs.setString(agentIdKey, agentId);
      }
      
      return agentId;
    } catch (e) {
      throw Exception('Failed to get or create agent ID: $e');
    }
  }

  static Future<Set<String>> _getSyncedLogIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncedLogs = prefs.getStringList(syncedLogsKey) ?? [];
      return syncedLogs.toSet();
    } catch (e) {
      throw Exception('Failed to get synced log IDs: $e');
    }
  }

  static Future<void> _saveSyncedLogIds(Set<String> logIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(syncedLogsKey, logIds.toList());
    } catch (e) {
      throw Exception('Failed to save synced log IDs: $e');
    }
  }

  static String _generateLogId(CallLog log) {
    final timestamp = log.startTime.millisecondsSinceEpoch;
    final duration = log.duration.inSeconds;
    final callType = log.type.toString();
    final phoneNumber = log.phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    
    final uniqueString = '$phoneNumber-$timestamp-$duration-$callType';
    return uniqueString;
  }

  static String _formatDuration(Duration duration) {
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
  }

  static bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }

  static Future<Map<String, dynamic>> syncCallLogs(List<CallLog> callLogs) async {
    try {
      final deviceId = await DeviceInfoService.getDeviceId();
      final agentId = await _getOrCreateAgentId();
      final syncedLogIds = await _getSyncedLogIds();
      
      int syncedCount = 0;
      int failedCount = 0;
      Set<String> newSyncedIds = Set.from(syncedLogIds);
      List<String> errorMessages = [];
      
      final todayLogs = callLogs.where((log) => _isToday(log.startTime)).toList();
      
      if (todayLogs.isEmpty) {
        return {
          'success': false,
          'message': 'No call logs found for today',
          'syncedCount': 0,
          'failedCount': 0
        };
      }

      for (var log in todayLogs) {
        final logId = _generateLogId(log);
        
        if (syncedLogIds.contains(logId)) {
          continue;
        }

        try {
          final response = await http.post(
            Uri.parse(baseUrl),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'name': log.contactName,
              'duration': '${log.duration.inMinutes}m',
              'start_time': log.startTime.toUtc().toIso8601String(),
              'end_time': log.endTime.toUtc().toIso8601String(),
              'status': log.type.toString().split('.').last,
              'device_id': deviceId,
              'agent_id': agentId,
            }),
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Request timed out');
            },
          );

          if (response.statusCode == 201) {
            newSyncedIds.add(logId);
            syncedCount++;
          } else {
            failedCount++;
            final errorBody = response.body.isNotEmpty 
                ? response.body 
                : 'Server returned status code ${response.statusCode}';
            errorMessages.add('Failed to sync call from ${log.contactName}: $errorBody');
          }
        } on TimeoutException catch (e) {
          failedCount++;
          errorMessages.add('Timeout while syncing call from ${log.contactName}: ${e.message}');
        } on http.ClientException catch (e) {
          failedCount++;
          errorMessages.add('Network error while syncing call from ${log.contactName}: $e');
        } catch (e) {
          failedCount++;
          errorMessages.add('Error syncing call from ${log.contactName}: $e');
        }
      }

      if (syncedCount > 0) {
        try {
          await _saveSyncedLogIds(newSyncedIds);
        } catch (e) {
          errorMessages.add('Failed to save sync status: $e');
        }
      }

      if (failedCount > 0) {
        return {
          'success': false,
          'message': 'Some calls failed to sync',
          'syncedCount': syncedCount,
          'failedCount': failedCount,
          'errors': errorMessages
        };
      }

      return {
        'success': true,
        'message': 'Successfully synced $syncedCount calls',
        'syncedCount': syncedCount,
        'failedCount': 0
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error in sync process: $e',
        'syncedCount': 0,
        'failedCount': 0,
        'errors': [e.toString()]
      };
    }
  }
} 