import 'package:flutter/material.dart';
import '../../theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  // Push toggles
  bool _pushStatus = true;
  bool _pushMessages = true;
  bool _pushPromos = false;
  
  // Email toggles
  bool _emailStatus = true;
  bool _emailMessages = true;
  bool _emailCredits = true;
  bool _emailPromos = false;

  bool _isLoading = false;

  void _saveSettings() async {
    setState(() => _isLoading = true);
    // Simulate API save
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferences saved'), backgroundColor: AppTheme.success),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageAlt,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(color: AppTheme.navy700, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('PUSH NOTIFICATIONS'),
                    Container(
                      color: AppTheme.white,
                      child: Column(
                        children: [
                          _buildToggle('Status updates', 'When your pro is on the way or arrived', _pushStatus, (v) => setState(() => _pushStatus = v)),
                          const Divider(height: 1, indent: 16),
                          _buildToggle('New messages', 'When a pro sends you a message', _pushMessages, (v) => setState(() => _pushMessages = v)),
                          const Divider(height: 1, indent: 16),
                          _buildToggle('Promotions & Tips', 'Occasional offers and maintenance tips', _pushPromos, (v) => setState(() => _pushPromos = v)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.tealTint,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: AppTheme.teal700, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Push notifications open the relevant work order directly. Live status updates poll every 60 seconds while the app is open.',
                              style: TextStyle(color: AppTheme.teal700, fontSize: 12, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionHeader('EMAIL NOTIFICATIONS'),
                    Container(
                      color: AppTheme.white,
                      child: Column(
                        children: [
                          _buildToggle('Status updates & receipts', 'Important booking lifecycle updates', _emailStatus, (v) => setState(() => _emailStatus = v)),
                          const Divider(height: 1, indent: 16),
                          _buildToggle('Unread messages', 'If you miss a chat from a pro', _emailMessages, (v) => setState(() => _emailMessages = v)),
                          const Divider(height: 1, indent: 16),
                          _buildToggle('Service credits', 'When you earn credits after a completed job', _emailCredits, (v) => setState(() => _emailCredits = v)),
                          const Divider(height: 1, indent: 16),
                          _buildToggle('Promotions & Tips', 'Occasional offers and maintenance tips', _emailPromos, (v) => setState(() => _emailPromos = v)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.white,
                border: Border(top: BorderSide(color: AppTheme.line)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.orange500,
                    foregroundColor: AppTheme.navy700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.navy700))
                      : const Text('Save preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Text(
        title,
        style: const TextStyle(color: AppTheme.gray, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.05),
      ),
    );
  }

  Widget _buildToggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.navy700, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.gray, fontSize: 12)),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.teal500,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
