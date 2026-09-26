import 'package:flutter/material.dart';

import '../theme.dart';

/// Public, account-free surfaces. These deliberately contain no homeowner API
/// calls: visitors can browse the marketplace before creating an account.
class GuestHomeTab extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onCategory;
  final VoidCallback onCreateAccount;
  final VoidCallback onSignIn;

  const GuestHomeTab({
    super.key,
    required this.onSearch,
    required this.onCategory,
    required this.onCreateAccount,
    required this.onSignIn,
  });

  @override
  State<GuestHomeTab> createState() => _GuestHomeTabState();
}

class _GuestHomeTabState extends State<GuestHomeTab> {
  final _searchController = TextEditingController();
  String _zip = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _editZip() async {
    final controller = TextEditingController(text: _zip);
    final zip = await showDialog<String>(
      context: context,
      builder: (context) => _ZipEntryDialog(controller: controller),
    );
    controller.dispose();
    if (zip != null && mounted) setState(() => _zip = zip);
  }

  void _search() {
    final query = _searchController.text.trim();
    widget.onSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    const categories = <_GuestCategory>[
      _GuestCategory('HVAC', Icons.air, AppTheme.blueTint),
      _GuestCategory('Plumbing', Icons.water_drop_outlined, AppTheme.blueTint),
      _GuestCategory('Electrical', Icons.bolt_outlined, AppTheme.amberTint),
      _GuestCategory(
          'Cleaning', Icons.auto_awesome_outlined, AppTheme.greenTint),
      _GuestCategory('Roofing', Icons.roofing_outlined, Color(0xFFFFEBEE)),
      _GuestCategory('Lawn', Icons.content_cut_outlined, AppTheme.greenTint),
      _GuestCategory('Handyman', Icons.handyman_outlined, Color(0xFFF3E5F5)),
      _GuestCategory('All 31', Icons.grid_view_rounded, AppTheme.orange500,
          isAccent: true),
    ];
    return ColoredBox(
      color: AppTheme.pageBackground,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [AppTheme.navy700, AppTheme.teal500],
              ),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                InkWell(
                  onTap: _editZip,
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 28,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 5),
                        Text(
                          _zip.isEmpty ? 'Enter ZIP code' : _zip,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 1),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.help_outline_rounded,
                    color: Colors.white, size: 21),
              ]),
              const SizedBox(height: 17),
              const Text('What do you need done?',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              Container(
                height: 48,
                padding: const EdgeInsets.only(left: 14, right: 6),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.search,
                      color: AppTheme.textTertiary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: (_) => _search(),
                      decoration: const InputDecoration(
                        hintText: 'Search a service or pro',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  const Icon(Icons.camera_alt_outlined,
                      color: AppTheme.textTertiary, size: 19),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: _search,
                    borderRadius: BorderRadius.circular(18),
                    child: const CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.orange500,
                      child: Icon(Icons.arrow_forward,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Browse by category',
                    style: TextStyle(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
                const Spacer(),
                TextButton(
                    onPressed: () => widget.onCategory('All'),
                    child: const Text('See all 31 ›')),
              ]),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.05,
                ),
                itemCount: categories.length,
                itemBuilder: (context, i) {
                  final item = categories[i];
                  return InkWell(
                    onTap: () => widget.onCategory(
                        item.label == 'All 31' ? 'All' : item.label),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                          color: item.color,
                          borderRadius: BorderRadius.circular(12),
                          border: item.isAccent
                              ? null
                              : Border.all(color: AppTheme.cardBorder)),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(item.icon,
                                color:
                                    item.isAccent ? Colors.white : AppTheme.ink,
                                size: 21),
                            const SizedBox(height: 5),
                            Text(item.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: item.isAccent
                                        ? Colors.white
                                        : AppTheme.ink,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700)),
                          ]),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              const Text('Sign up',
                  style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.orange500)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CREATE YOUR ACCOUNT',
                          style: TextStyle(
                              color: AppTheme.orange500,
                              fontSize: 11,
                              letterSpacing: .5,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      const Text(
                          'Create an account to book services, save your home details, earn rewards, and get personalized recommendations.',
                          style: TextStyle(
                              color: AppTheme.ink,
                              fontSize: 13.5,
                              height: 1.35,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      const Text('It only takes a minute to get started',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11)),
                      const SizedBox(height: 10),
                      SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                              onPressed: widget.onCreateAccount,
                              child: const Text('Create account'))),
                      Center(
                          child: TextButton(
                              onPressed: widget.onSignIn,
                              child: const Text(
                                  'Already have an account? Sign in'))),
                    ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class GuestGateTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onCreateAccount;
  final VoidCallback onSignIn;
  const GuestGateTab(
      {super.key,
      required this.icon,
      required this.title,
      required this.message,
      required this.onCreateAccount,
      required this.onSignIn});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AppTheme.pageBackground,
        child: Center(
            child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.cardBorder)),
                child: Icon(icon, color: AppTheme.teal500, size: 38)),
            const SizedBox(height: 24),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.navy700,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14, height: 1.35)),
            const SizedBox(height: 22),
            ElevatedButton(
                onPressed: onCreateAccount,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.orange500,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 30)),
                child: const Text('Create account',
                    style: TextStyle(fontWeight: FontWeight.w800))),
            const SizedBox(height: 10),
            TextButton(
                onPressed: onSignIn,
                child: const Text('Already have an account? Sign in')),
          ]),
        )),
      );
}

class _GuestCategory {
  final String label;
  final IconData icon;
  final Color color;
  final bool isAccent;
  const _GuestCategory(this.label, this.icon, this.color,
      {this.isAccent = false});
}

class _ZipEntryDialog extends StatefulWidget {
  final TextEditingController controller;
  const _ZipEntryDialog({required this.controller});
  @override
  State<_ZipEntryDialog> createState() => _ZipEntryDialogState();
}

class _ZipEntryDialogState extends State<_ZipEntryDialog> {
  String? error;
  @override
  Widget build(BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter ZIP code',
                      style: TextStyle(
                          color: AppTheme.navy700,
                          fontSize: 21,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 17),
                  TextField(
                      controller: widget.controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      decoration: InputDecoration(
                          counterText: '',
                          prefixIcon: const Icon(Icons.location_on_outlined,
                              color: AppTheme.orange500),
                          errorText: error,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppTheme.cardBorder)))),
                  const SizedBox(height: 10),
                  const Text(
                      'This only changes the ZIP used in your local browser test session.',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.35)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: ElevatedButton(
                            onPressed: () {
                              final zip = widget.controller.text
                                  .replaceAll(RegExp(r'\D'), '');
                              if (zip.length != 5) {
                                setState(() =>
                                    error = 'Enter a valid 5-digit ZIP code');
                                return;
                              }
                              Navigator.pop(context, zip);
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.orange500,
                                foregroundColor: Colors.white),
                            child: const Text('Save')))
                  ]),
                ])),
      );
}
