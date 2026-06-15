class BeneficiaryDraft {
  final String fullName;
  final String nationalId;
  final String phone;
  final String programId;
  final String tenantId;
  final String locationId;
  final String createdBy;

  final String? gender;
  final String? dateOfBirth;
  final int? householdSize;
  final String? address;
  final String? notes;
  final String? registeredBy;

  BeneficiaryDraft({
    required this.fullName,
    required this.nationalId,
    required this.phone,
    required this.programId,
    required this.tenantId,
    required this.locationId,
    required this.createdBy,
    this.gender,
    this.dateOfBirth,
    this.householdSize,
    this.address,
    this.notes,
    this.registeredBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'national_id': nationalId,
      'phone': phone,
      'program_id': programId,
      'tenant_id': tenantId,
      'location_id': locationId,
      'created_by': createdBy,
      'registered_by': registeredBy ?? createdBy,
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'household_size': householdSize,
      'address': address,
      'notes': notes,
      'status': 'active',
    };
  }
}