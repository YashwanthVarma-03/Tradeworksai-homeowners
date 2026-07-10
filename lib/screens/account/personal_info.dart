import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/auth_service.dart';
import '../../services/homeowner_service.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({Key? key}) : super(key: key);

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  
  bool _isLoading = false;
  String _originalEmail = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: '${AuthService.instance.givenName ?? ''} ${AuthService.instance.familyName ?? ''}'.trim());
    _phoneController = TextEditingController(text: '(813) 555-0192'); // Placeholder data
    _originalEmail = AuthService.instance.userEmail ?? '';
    _emailController = TextEditingController(text: _originalEmail);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Split name
      final parts = _nameController.text.trim().split(' ');
      final givenName = parts.isNotEmpty ? parts.first : '';
      final familyName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      
      await HomeownerService.instance.updateProfile(
        givenName: givenName,
        familyName: familyName,
        phone: _phoneController.text,
        email: _emailController.text,
        userName: _emailController.text,
        preferredContact: 'email',
        marketingConsent: true,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully'), backgroundColor: AppTheme.success),
        );
        Navigator.pop(context, true); // return true to indicate change
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Personal info', style: TextStyle(color: AppTheme.navy700, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Full name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.ink)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Jane Doe',
                          hintStyle: const TextStyle(color: AppTheme.gray),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.line)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.line)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                        validator: (val) => (val == null || val.isEmpty) ? 'Name is required' : null,
                      ),
                      
                      const SizedBox(height: 16),
                      const Text('Phone number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.ink)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: '(555) 123-4567',
                          hintStyle: const TextStyle(color: AppTheme.gray),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.line)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.line)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                        validator: (val) => (val == null || val.isEmpty) ? 'Phone is required' : null,
                      ),
                      
                      const SizedBox(height: 16),
                      const Text('Email', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.ink)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'jane@example.com',
                          hintStyle: const TextStyle(color: AppTheme.gray),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.line)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.line)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Email is required';
                          if (!val.contains('@')) return 'Invalid email address';
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.tealTint,
                          border: const Border(left: BorderSide(color: AppTheme.teal500, width: 4)),
                          borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppTheme.teal700, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Changing your email address will require you to re-verify your account.',
                                style: TextStyle(color: AppTheme.teal700, fontSize: 12.5, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.orange500,
                    foregroundColor: AppTheme.navy700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.navy700))
                      : const Text('Save changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
