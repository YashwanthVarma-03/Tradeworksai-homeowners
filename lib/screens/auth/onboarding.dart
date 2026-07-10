import 'package:flutter/material.dart';
import '../../theme.dart';
import '../dashboard_shell.dart';
import '../../widgets/custom_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Step 1
  final _phoneController = TextEditingController();
  
  // Step 2
  final _addressController = TextEditingController();
  
  // Step 3
  bool _optInPush = true;
  bool _optInEmail = true;
  
  bool _isSaving = false;

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() async {
    setState(() => _isSaving = true);
    // Simulate API call to save profile info
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        createPremiumRoute(const DashboardShell()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with Progress
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (_currentPage + 1) / 3,
                      backgroundColor: AppTheme.line,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.orange500),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('${_currentPage + 1} of 3', style: const TextStyle(color: AppTheme.gray, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ],
              ),
            ),
            
            // Bottom Action
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.navy700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_currentPage == 2 ? 'Complete Setup' : 'Continue', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Icon(Icons.person_outline, size: 80, color: AppTheme.navy700.withOpacity(0.2)),
          ),
          const SizedBox(height: 32),
          const Text('Welcome to TradeWorks!', style: TextStyle(color: AppTheme.navy700, fontWeight: FontWeight.bold, fontSize: 24)),
          const SizedBox(height: 12),
          const Text('Let\'s set up your profile so pros can contact you when needed.', style: TextStyle(color: AppTheme.ink, fontSize: 15, height: 1.4)),
          const SizedBox(height: 32),
          const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: '(555) 555-5555',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.orange500)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Icon(Icons.home_outlined, size: 80, color: AppTheme.navy700.withOpacity(0.2)),
          ),
          const SizedBox(height: 32),
          const Text('Where is your home?', style: TextStyle(color: AppTheme.navy700, fontWeight: FontWeight.bold, fontSize: 24)),
          const SizedBox(height: 12),
          const Text('Add your primary residence. You can manage multiple addresses later.', style: TextStyle(color: AppTheme.ink, fontSize: 15, height: 1.4)),
          const SizedBox(height: 32),
          const Text('Home Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              hintText: 'Start typing your address...',
              prefixIcon: const Icon(Icons.search, color: AppTheme.gray),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.orange500)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Icon(Icons.notifications_active_outlined, size: 80, color: AppTheme.navy700.withOpacity(0.2)),
          ),
          const SizedBox(height: 32),
          const Text('Stay in the loop', style: TextStyle(color: AppTheme.navy700, fontWeight: FontWeight.bold, fontSize: 24)),
          const SizedBox(height: 12),
          const Text('Get timely updates when your pro is on the way or sends a message.', style: TextStyle(color: AppTheme.ink, fontSize: 15, height: 1.4)),
          const SizedBox(height: 32),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppTheme.tealTint, shape: BoxShape.circle),
                  child: const Icon(Icons.notifications, color: AppTheme.teal700, size: 20),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 4),
                      Text('Status updates & messages', style: TextStyle(color: AppTheme.gray, fontSize: 12)),
                    ],
                  ),
                ),
                Switch(
                  value: _optInPush,
                  onChanged: (v) => setState(() => _optInPush = v),
                  activeColor: AppTheme.orange500,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppTheme.tealTint, shape: BoxShape.circle),
                  child: const Icon(Icons.email, color: AppTheme.teal700, size: 20),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 4),
                      Text('Receipts & detailed quotes', style: TextStyle(color: AppTheme.gray, fontSize: 12)),
                    ],
                  ),
                ),
                Switch(
                  value: _optInEmail,
                  onChanged: (v) => setState(() => _optInEmail = v),
                  activeColor: AppTheme.orange500,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
