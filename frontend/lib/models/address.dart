import 'paginated.dart';

/// Mirrors `accounts.serializers.AddressSerializer`.
///
/// `Address.user` is a OneToOneField and the serializer's `create` rejects a
/// second address, so a customer has at most one. The endpoint is still a
/// ModelViewSet, hence the list/detail URL shape.
class Address {
  const Address({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.address1,
    required this.city,
    required this.postalCode,
    required this.region,
    this.company = '',
    this.address2 = '',
    this.country = 'Bangladesh',
  });

  final int id;
  final String firstName;
  final String lastName;
  final String company;
  final String address1;
  final String address2;
  final String city;
  final String postalCode;
  final String country;
  final String region;

  String get recipient => '$firstName $lastName'.trim();

  /// Human-readable single-line form used in the checkout summary.
  String get formatted {
    final parts = <String>[
      address1,
      if (address2.trim().isNotEmpty) address2,
      city,
      region,
      postalCode,
      country,
    ].where((p) => p.trim().isNotEmpty);
    return parts.join(', ');
  }

  factory Address.fromJson(Map<String, dynamic> json) => Address(
    id: parseInt(json['id']),
    firstName: (json['first_name'] ?? '') as String,
    lastName: (json['last_name'] ?? '') as String,
    company: (json['company'] ?? '') as String,
    address1: (json['address1'] ?? '') as String,
    address2: (json['address2'] ?? '') as String,
    city: (json['city'] ?? '') as String,
    postalCode: (json['postal_code'] ?? '') as String,
    country: (json['country'] ?? 'Bangladesh') as String,
    region: (json['region'] ?? '') as String,
  );

  /// `user` is intentionally omitted — the ViewSet injects `request.user` in
  /// `perform_create`, and the guideline explicitly says not to send it.
  Map<String, dynamic> toJson() => {
    'first_name': firstName,
    'last_name': lastName,
    'company': company,
    'address1': address1,
    'address2': address2,
    'city': city,
    'postal_code': postalCode,
    'country': country,
    'region': region,
  };
}
