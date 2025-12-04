class PaoModel {
  final String id;
  final String routeName;
  final String position;
  final bool isVerified;
  final String lastName;
  final String middleName;
  final bool isActive;
  final bool isLocationEnabled;
  final double? lat; // ✅ ADDED
  final double? lng; // ✅ ADDED

  PaoModel({
    required this.id,
    required this.routeName,
    required this.position,
    required this.isVerified,
    required this.lastName,
    required this.middleName,
    this.isActive = false,
    this.isLocationEnabled = false,
    this.lat, // ✅ ADDED
    this.lng, // ✅ ADDED
  });

  factory PaoModel.fromFirestore(Map<String, dynamic> data, String id) {
    return PaoModel(
      id: id,
      routeName: data['routeName'] ?? '',
      position: data['position'] ?? '',
      isVerified: data['isVerified'] ?? false,
      lastName: data['lastName'] ?? '',
      middleName: data['middleName'] ?? '',
      isActive: data['isActive'] ?? false,
      isLocationEnabled: data['isLocationEnabled'] ?? false,
      lat: (data['lat'] as num?)?.toDouble(), // ✅ ADDED
      lng: (data['lng'] as num?)?.toDouble(), // ✅ ADDED
    );
  }
}