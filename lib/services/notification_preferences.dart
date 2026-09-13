class NotificationPreferences {
  const NotificationPreferences({
    required this.pushStatus,
    required this.pushMessages,
    required this.pushCredits,
    required this.pushPromos,
    required this.emailReceipts,
    required this.emailPromos,
  });

  final bool pushStatus;
  final bool pushMessages;
  final bool pushCredits;
  final bool pushPromos;
  final bool emailReceipts;
  final bool emailPromos;

  bool get hasPushEnabled =>
      pushStatus || pushMessages || pushCredits || pushPromos;

  Map<String, bool> toJson() => {
        'pushStatus': pushStatus,
        'pushMessages': pushMessages,
        'pushCredits': pushCredits,
        'pushPromos': pushPromos,
        'emailReceipts': emailReceipts,
        'emailPromos': emailPromos,
      };
}
