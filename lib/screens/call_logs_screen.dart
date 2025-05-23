import 'package:flutter/material.dart';
import '../models/call_log.dart';
import '../services/call_log_service.dart';
import 'device_info_screen.dart';

class CallLogsScreen extends StatefulWidget {
  const CallLogsScreen({super.key});

  @override
  State<CallLogsScreen> createState() => _CallLogsScreenState();
}

class _CallLogsScreenState extends State<CallLogsScreen> {
  List<CallLog> _callLogs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCallLogs();
  }

  Future<void> _loadCallLogs() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final logs = await CallLogService.getCallLogs();
      setState(() {
        _callLogs = logs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_android),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DeviceInfoScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCallLogs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: $_error',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadCallLogs,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _callLogs.isEmpty
                  ? const Center(
                      child: Text('No call logs found'),
                    )
                  : ListView.builder(
                      itemCount: _callLogs.length,
                      itemBuilder: (context, index) {
                        final log = _callLogs[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: log.callTypeColor.withOpacity(0.2),
                            child: Icon(
                              log.callTypeIcon,
                              color: log.callTypeColor,
                            ),
                          ),
                          title: Text(log.contactName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(log.phoneNumber),
                              Text(
                                '${log.formattedDate} at ${log.formattedTime}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                log.formattedDuration,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                log.type.toString().split('.').last,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: log.callTypeColor,
                                    ),
                              ),
                            ],
                          ),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(log.contactName),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Phone: ${log.phoneNumber}'),
                                    const SizedBox(height: 8),
                                    Text('Date: ${log.formattedDate}'),
                                    const SizedBox(height: 8),
                                    Text('Time: ${log.formattedTime}'),
                                    const SizedBox(height: 8),
                                    Text('Duration: ${log.formattedDuration}'),
                                    const SizedBox(height: 8),
                                    Text('Type: ${log.type.toString().split('.').last}'),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
    );
  }
} 