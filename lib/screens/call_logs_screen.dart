import 'package:flutter/material.dart';
import '../models/call_log.dart';
import '../services/call_log_service.dart';
import '../services/api_service.dart';
import 'device_info_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'analytics_screen.dart';

class CallLogsScreen extends StatefulWidget {
  const CallLogsScreen({super.key});

  @override
  State<CallLogsScreen> createState() => _CallLogsScreenState();
}

class _CallLogsScreenState extends State<CallLogsScreen> {
  List<CallLog> _callLogs = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _error;
  String _searchQuery = '';
  int _selectedFilter = 0; // 0: All, 1: Incoming, 2: Outgoing, 3: Missed, 4: Rejected

  final List<Map<String, dynamic>> _filters = [
    {'icon': Icons.call, 'label': 'All', 'color': Colors.black},
    {'icon': Icons.call_received, 'label': 'Incoming', 'color': Colors.green},
    {'icon': Icons.call_made, 'label': 'Outgoing', 'color': Colors.orange},
    {'icon': Icons.call_missed, 'label': 'Missed', 'color': Colors.red},
    {'icon': Icons.call_end, 'label': 'Rejected', 'color': Colors.redAccent},
  ];

  final Set<String> _whatsAppUnavailable = {};
  final Map<String, String> _notes = {};

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

      final prevLogKeys = _callLogs.map((log) => '${log.phoneNumber}_${log.startTime.millisecondsSinceEpoch}').toSet();
      final logs = await CallLogService.getCallLogs();
      final newLogKeys = logs.map((log) => '${log.phoneNumber}_${log.startTime.millisecondsSinceEpoch}').toSet();
      final isNewCall = newLogKeys.difference(prevLogKeys).isNotEmpty;

      setState(() {
        _callLogs = logs;
        _isLoading = false;
      });

      if (isNewCall) {
        // Auto-sync if new call detected
        _syncCallLogs();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _syncCallLogs() async {
    try {
      setState(() {
        _isSyncing = true;
        _error = null;
      });

      final result = await ApiService.syncCallLogs(_callLogs);
      
      if (mounted) {
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          // Show error dialog with detailed information
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Sync Status'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result['message'],
                      style: const TextStyle(color: Colors.red),
                    ),
                    if (result['syncedCount'] > 0) ...[
                      const SizedBox(height: 8),
                      Text('Successfully synced: ${result['syncedCount']} calls'),
                    ],
                    if (result['failedCount'] > 0) ...[
                      const SizedBox(height: 8),
                      Text('Failed to sync: ${result['failedCount']} calls'),
                    ],
                    if (result['errors'] != null) ...[
                      const SizedBox(height: 8),
                      const Text('Error details:'),
                      const SizedBox(height: 4),
                      ...result['errors'].map((error) => Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text('• $error'),
                      )),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sync Error'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  List<CallLog> get _filteredLogs {
    List<CallLog> logs = _callLogs;
    if (_selectedFilter != 0) {
      logs = logs.where((log) {
        switch (_selectedFilter) {
          case 1:
            return log.type == CallType.incoming;
          case 2:
            return log.type == CallType.outgoing;
          case 3:
            return log.type == CallType.missed;
          // case 4: // Rejected (not implemented in model)
          //   return false;
          default:
            return true;
        }
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      logs = logs.where((log) =>
        log.contactName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        log.phoneNumber.contains(_searchQuery)
      ).toList();
    }
    return logs;
  }

  Map<String, List<CallLog>> get _logsByDate {
    final Map<String, List<CallLog>> grouped = {};
    for (var log in _filteredLogs) {
      final date = log.formattedDate;
      if (!grouped.containsKey(date)) grouped[date] = [];
      grouped[date]!.add(log);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Text(
                    'Call History',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            // Filter Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_filters.length, (i) {
                  final filter = _filters[i];
                  final selected = _selectedFilter == i;
                  // Define unique gradients for each filter
                  final List<List<Color>> gradients = [
                    [Color(0xFF4A90E2), Color(0xFF50E3C2)], // All
                    [Color(0xFF43E97B), Color(0xFF38F9D7)], // Incoming
                    [Color(0xFFFFB75E), Color(0xFFED8F03)], // Outgoing
                    [Color(0xFFFF5858), Color(0xFFFFAE53)], // Missed
                    [Color(0xFFB24592), Color(0xFFF15F79)], // Rejected
                  ];
                  final List<Color> gradientColors = gradients[i];
                  final Color mainColor = gradientColors[0];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedFilter = i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: selected ? 44 : 38,
                            height: selected ? 44 : 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: selected
                                    ? gradientColors
                                    : [Color(0xFFE0E0E0), Color(0xFFF5F5F5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: mainColor.withOpacity(0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [],
                              border: selected
                                  ? Border.all(color: mainColor, width: 2)
                                  : null,
                            ),
                            child: Icon(
                              filter['icon'],
                              color: Colors.white,
                              size: selected ? 28 : 24,
          ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            filter['label'],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selected ? mainColor : Colors.grey[600],
                              fontSize: selected ? 13 : 12,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              letterSpacing: 0.1,
                            ),
          ),
        ],
      ),
                    ),
                  );
                }),
              ),
            ),
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            // Call Logs List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadCallLogs,
                child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
                        ? ListView(
                            children: [
                              SizedBox(height: 100),
                              Center(
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
                              ),
                            ],
                )
                        : _filteredLogs.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 100),
                                  Center(child: Text('No call logs found')),
                                ],
                    )
                            : ListView(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                children: _logsByDate.entries.expand((entry) {
                                  final date = entry.key;
                                  final logs = entry.value;
                                  return [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                      child: Text(
                                        date,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                            ),
                          ),
                                    ),
                                    ...logs.map((log) => _buildCallLogCard(log)).toList(),
                                  ];
                                }).toList(),
                              ),
              ),
            ),
            // Bottom Navigation Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                              ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                              ),
                            ],
                          ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                  GestureDetector(
                          onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AnalyticsScreen(callLogs: _callLogs),
                        ),
                      );
                    },
                    child: _buildNavBarItem(Icons.analytics, 'Analytics', 0),
                              ),
                  _buildNavBarItem(Icons.contacts, 'Contacts', 1),
                  _buildNavBarItem(Icons.call, 'Call History', 2, selected: true),
                  _buildNavBarItem(Icons.dashboard, 'Dashboard', 3),
                  _buildNavBarItem(Icons.menu, 'More', 4),
                ],
                                    ),
                              ),
                            ],
                          ),
      ),
    );
  }

  Widget _buildCallLogCard(CallLog log) {
    final noteKey = '${log.phoneNumber}_${log.startTime.millisecondsSinceEpoch}';
    final note = _notes[noteKey];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: log.callTypeColor.withOpacity(0.2),
                  child: Icon(log.callTypeIcon, color: log.callTypeColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                      Text(
                        log.contactName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        log.phoneNumber,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Text(
                  log.formattedStartTime,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                Text(
                  log.formattedDuration,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
                                    const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.copy, color: Colors.grey[400], size: 24),
                  tooltip: 'Copy',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: log.phoneNumber));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Phone number copied!')),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.message, color: Colors.blue[400], size: 24),
                  tooltip: 'Message',
                  onPressed: () async {
                    final smsPermission = await Permission.sms.request();
                    if (!smsPermission.isGranted) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('SMS permission denied.')),
                        );
                      }
                      return;
                    }
                    final smsUri = Uri.parse('sms:${log.phoneNumber}');
                    if (await canLaunchUrl(smsUri)) {
                      await launchUrl(smsUri);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not open SMS app.')),
                        );
                      }
                    }
                  },
                ),
                IconButton(
                  icon: FaIcon(
                    FontAwesomeIcons.whatsapp,
                    color: _whatsAppUnavailable.contains(log.phoneNumber)
                        ? Colors.grey
                        : Color(0xFF25D366),
                    size: 24,
                  ),
                  tooltip: 'WhatsApp',
                  onPressed: _whatsAppUnavailable.contains(log.phoneNumber)
                      ? null
                      : () async {
                          final phone = log.phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
                          final waUri = Uri.parse('https://wa.me/$phone');
                          // Check if WhatsApp is installed
                          final whatsappInstalled = await canLaunchUrl(waUri);
                          if (whatsappInstalled) {
                            await launchUrl(waUri, mode: LaunchMode.externalApplication);
                          } else {
                            setState(() {
                              _whatsAppUnavailable.add(log.phoneNumber);
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('WhatsApp not available for this number or not installed.')),
                              );
                            }
                          }
                        },
                ),
                IconButton(
                  icon: Icon(Icons.call, color: Colors.blue, size: 24),
                  tooltip: 'Call',
                  onPressed: () async {
                    final phonePermission = await Permission.phone.request();
                    if (!phonePermission.isGranted) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Phone permission denied.')),
                        );
                      }
                      return;
                    }
                    final telUri = Uri.parse('tel:${log.phoneNumber}');
                    if (await canLaunchUrl(telUri)) {
                      await launchUrl(telUri);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not open dialer.')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
                                    const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final controller = TextEditingController(text: note);
                final result = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Add Note'),
                    content: TextField(
                      controller: controller,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Enter your note here...',
                        border: OutlineInputBorder(),
                      ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, controller.text.trim()),
                        child: const Text('Save'),
                                  ),
                                ],
                              ),
                            );
                if (result != null) {
                  setState(() {
                    if (result.isEmpty) {
                      _notes.remove(noteKey);
                    } else {
                      _notes[noteKey] = result;
                    }
                  });
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.note, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note == null || note.isEmpty
                            ? 'Tap to here add notes'
                            : note,
                        style: TextStyle(
                          color: note == null || note.isEmpty ? Colors.grey : Colors.black87,
                          fontSize: 13,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
                        );
  }

  Widget _buildNavBarItem(IconData icon, String label, int index, {bool selected = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: selected ? Colors.black : Colors.grey),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.grey,
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
} 