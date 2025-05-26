import 'package:flutter/material.dart';
import '../models/call_log.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatefulWidget {
  final List<CallLog> callLogs;
  const AnalyticsScreen({Key? key, required this.callLogs}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedFilter = 'Today';
  DateTimeRange? _dateRange;
  int _currentSection = 0;
  final PageController _pageController = PageController();

  final List<String> _filters = [
    'Today',
    'Yesterday',
    'Current Week',
    'Current Month',
    'All',
  ];

  @override
  void initState() {
    super.initState();
    _setInitialDateRange();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _setInitialDateRange() {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case 'Today':
        _dateRange = DateTimeRange(start: DateTime(now.year, now.month, now.day), end: DateTime(now.year, now.month, now.day, 23, 59, 59));
        break;
      case 'Yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        _dateRange = DateTimeRange(start: DateTime(yesterday.year, yesterday.month, yesterday.day), end: DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59));
        break;
      case 'Current Week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        _dateRange = DateTimeRange(start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day), end: DateTime(now.year, now.month, now.day, 23, 59, 59));
        break;
      case 'Current Month':
        _dateRange = DateTimeRange(start: DateTime(now.year, now.month, 1), end: DateTime(now.year, now.month, now.day, 23, 59, 59));
        break;
      case 'All':
        _dateRange = null;
        break;
    }
  }

  void _onFilterChanged(String? value) {
    if (value == null) return;
    setState(() {
      _selectedFilter = value;
      _setInitialDateRange();
    });
  }

  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  List<CallLog> get _filteredLogs {
    if (_dateRange == null) return widget.callLogs;
    return widget.callLogs.where((log) {
      return log.startTime.isAfter(_dateRange!.start.subtract(const Duration(seconds: 1))) &&
             log.startTime.isBefore(_dateRange!.end.add(const Duration(seconds: 1)));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _filteredLogs;
    final totalCalls = filteredLogs.length;
    final incoming = filteredLogs.where((c) => c.type == CallType.incoming).length;
    final outgoing = filteredLogs.where((c) => c.type == CallType.outgoing).length;
    final missed = filteredLogs.where((c) => c.type == CallType.missed).length;
    final rejected = 0; // Add logic if you have rejected type
    final totalDuration = filteredLogs.fold<Duration>(Duration.zero, (sum, c) => sum + c.duration);
    String formattedDuration = '';
    if (totalDuration.inHours > 0) {
      formattedDuration = '${totalDuration.inHours}h ${totalDuration.inMinutes % 60}m';
    } else if (totalDuration.inMinutes > 0) {
      formattedDuration = '${totalDuration.inMinutes}m ${totalDuration.inSeconds % 60}s';
    } else {
      formattedDuration = '${totalDuration.inSeconds}s';
    }

    // Analysis calculations
    String topCaller = '-';
    int topCallerCount = 0;
    String longestCallContact = '-';
    Duration longestCallDuration = Duration.zero;
    String highestTotalContact = '-';
    Duration highestTotalDuration = Duration.zero;
    double avgCallDuration = 0;
    int connectedCalls = incoming + outgoing;

    if (filteredLogs.isNotEmpty) {
      // Top caller
      final Map<String, int> callCounts = {};
      for (var log in filteredLogs) {
        callCounts[log.contactName] = (callCounts[log.contactName] ?? 0) + 1;
      }
      final sortedCallers = callCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topCaller = sortedCallers.first.key;
      topCallerCount = sortedCallers.first.value;

      // Longest call
      final longest = filteredLogs.reduce((a, b) => a.duration > b.duration ? a : b);
      longestCallContact = longest.contactName;
      longestCallDuration = longest.duration;

      // Highest total call duration
      final Map<String, Duration> durationMap = {};
      for (var log in filteredLogs) {
        durationMap[log.contactName] = (durationMap[log.contactName] ?? Duration.zero) + log.duration;
      }
      final sortedDurations = durationMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      highestTotalContact = sortedDurations.first.key;
      highestTotalDuration = sortedDurations.first.value;

      // Average call duration
      avgCallDuration = totalDuration.inSeconds / filteredLogs.length;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Text(
                'Analytics',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButton<String>(
                    value: _selectedFilter,
                    items: _filters.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                    onChanged: _onFilterChanged,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  const SizedBox(height: 8),
                  if (_dateRange != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'From: ${_formatDate(_dateRange!.start)}  To: ${_formatDate(_dateRange!.end)}',
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                      ),
                    ),
                  if (_dateRange == null)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text('All Dates', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Section Switcher Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _sectionTab('Summary', 0),
                  const SizedBox(width: 12),
                  _sectionTab('Analysis', 1),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Section Content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentSection = i),
                children: [
                  // Summary Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.25,
                      children: [
                        _summaryCardModern(
                          icon: Icons.call,
                          iconColor: Colors.blue[400]!,
                          label: 'Total Phone Calls',
                          value: totalCalls.toString(),
                          duration: formattedDuration,
                        ),
                        _summaryCardModern(
                          icon: Icons.call_received,
                          iconColor: Colors.green,
                          label: 'Incoming Calls',
                          value: incoming.toString(),
                          duration: _formatDuration(filteredLogs.where((c) => c.type == CallType.incoming).fold(Duration.zero, (sum, c) => sum + c.duration)),
                        ),
                        _summaryCardModern(
                          icon: Icons.call_made,
                          iconColor: Colors.orange,
                          label: 'Outgoing Calls',
                          value: outgoing.toString(),
                          duration: _formatDuration(filteredLogs.where((c) => c.type == CallType.outgoing).fold(Duration.zero, (sum, c) => sum + c.duration)),
                        ),
                        _summaryCardModern(
                          icon: Icons.call_missed,
                          iconColor: Colors.red,
                          label: 'Missed Calls',
                          value: missed.toString(),
                        ),
                        _summaryCardModern(
                          icon: Icons.call_end,
                          iconColor: Colors.redAccent,
                          label: 'Rejected Calls',
                          value: '0', // Add logic if you have rejected type
                        ),
                        _summaryCardModern(
                          icon: Icons.phone_disabled,
                          iconColor: Colors.lightBlue,
                          label: 'Never Attended',
                          value: '0', // Add logic if you have this type
                        ),
                        _summaryCardModern(
                          icon: Icons.phone_missed,
                          iconColor: Colors.blueAccent,
                          label: 'Not Pickup by Client',
                          value: '0', // Add logic if you have this type
                        ),
                        _summaryCardModern(
                          icon: Icons.star_border,
                          iconColor: Colors.blueGrey,
                          label: 'Unique Calls',
                          value: filteredLogs.map((c) => c.phoneNumber).toSet().length.toString(),
                        ),
                      ],
                    ),
                  ),
                  // Analysis Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.25,
                      children: [
                        _analysisCardModern(
                          icon: Icons.person_outline,
                          iconColor: Colors.blueGrey,
                          title: 'Top Caller',
                          value: topCaller,
                        ),
                        _analysisCardModern(
                          icon: Icons.timer_outlined,
                          iconColor: Colors.deepPurple,
                          title: 'Longest Call',
                          value: _formatDuration(longestCallDuration),
                        ),
                        _analysisCardModern(
                          icon: Icons.timer_outlined,
                          iconColor: Colors.indigo,
                          title: 'Highest Total Call Duration',
                          value: _formatDuration(highestTotalDuration),
                        ),
                        _analysisCardModern(
                          icon: Icons.timer_outlined,
                          iconColor: Colors.teal,
                          title: 'Average Call Duration of Connected Calls',
                          value: avgCallDuration.isNaN ? '-' : '${avgCallDuration.toStringAsFixed(1)}s',
                          subtitle: 'Per Call & Per Day',
                        ),
                        _analysisCardModern(
                          icon: Icons.people_outline,
                          iconColor: Colors.blue,
                          title: 'Top 10 Frequently Talks',
                          value: '-',
                        ),
                        _analysisCardModern(
                          icon: Icons.timer_outlined,
                          iconColor: Colors.orange,
                          title: 'Top 10 Call Duration',
                          value: '-',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
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
            _navBarItem(context, Icons.analytics, 'Analytics', 0, selected: true),
            _navBarItem(context, Icons.contacts, 'Contacts', 1),
            _navBarItem(context, Icons.call, 'Call History', 2),
            _navBarItem(context, Icons.dashboard, 'Dashboard', 3),
            _navBarItem(context, Icons.menu, 'More', 4),
          ],
        ),
      ),
    );
  }

  Widget _summaryCardModern({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? duration,
  }) {
    return _AnimatedCard(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.call, color: Colors.grey[400], size: 18),
                const SizedBox(width: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            if (duration != null)
              Row(
                children: [
                  Icon(Icons.timer, color: Colors.grey[400], size: 18),
                  const SizedBox(width: 6),
                  Text(
                    duration,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _durationCard(BuildContext context, String duration) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        child: Row(
          children: [
            Icon(Icons.timer, color: Colors.deepPurple),
            const SizedBox(width: 16),
            Text(
              'Total Duration:',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800]),
            ),
            const SizedBox(width: 10),
            Text(
              duration,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple),
            ),
          ],
        ),
      ),
    );
  }

  Widget _analysisCard(String title, String value, {String? subtitle}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: value.isNotEmpty ? Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)) : null,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  Widget _sectionTab(String label, int index) {
    final bool selected = _currentSection == index;
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        setState(() => _currentSection = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _navBarItem(BuildContext context, IconData icon, String label, int index, {bool selected = false}) {
    return GestureDetector(
      onTap: () {
        if (selected) return;
        if (index == 0) return; // Already on Analytics
        if (index == 2) {
          Navigator.pop(context); // Go back to Call History
        } else {
          // You can add navigation for other tabs here
        }
      },
      child: Column(
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
      ),
    );
  }

  Widget _analysisCardModern({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    String? subtitle,
  }) {
    return _AnimatedCard(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Animated card widget for tap effect
class _AnimatedCard extends StatefulWidget {
  final Widget child;
  const _AnimatedCard({required this.child});
  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard> with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _scale < 1.0 ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
} 