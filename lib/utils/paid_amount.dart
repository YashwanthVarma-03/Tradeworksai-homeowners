/// Actual customer payment, including the live API's nested receipt summary.
/// A booking price, estimate or approved cap is not evidence of payment.
num? customerPaidAmount(Map<String, dynamic> job) {
  num? amount(dynamic value) {
    final n = value is num ? value : num.tryParse('$value');
    return n != null && n.isFinite && n >= 0 ? n : null;
  }

  final receipt = job['receiptReward'];
  for (final value in [
    job['customerPaidAmount'],
    if (receipt is Map) receipt['customerPaidAmount'],
    job['paidAmount'],
    job['paid_amount'],
  ]) {
    final n = amount(value);
    if (n != null) return n;
  }
  // Completed invoices are final; subtract credits, not a quoted amount.
  if (job['status'] == 'completed') {
    final invoice = amount(job['invoiceAmount']);
    final credits = amount(job['creditsApplied']);
    if (invoice != null && credits != null) {
      return (invoice - credits).clamp(0, invoice);
    }
  }
  return null;
}
