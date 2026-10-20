/// Booking uses contractor profile IDs and contractor offering IDs, never
/// Stream user IDs or catalogue service IDs.
abstract final class BookingIdentity {
  static String? text(dynamic value) {
    final result = value?.toString().trim() ?? '';
    return result.isEmpty || result == 'null' ? null : result;
  }

  static String? contractor(Map source) =>
      text(source['contractorId']) ??
      text(source['contractor_id']) ??
      text(source['contractorProfileId']) ??
      text(source['contractor_profile_id']);

  static String? offering(Map source, {bool offeringRecord = false}) =>
      text(source['contractorServiceId']) ??
      text(source['contractor_service_id']) ??
      text(source['serviceOptionId']) ??
      text(source['service_option_id']) ??
      (offeringRecord ? text(source['id']) : null) ??
      text(source['serviceId']);
}
