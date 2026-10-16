import 'paginated.dart';

/// Mirrors `accounts.serializers.UserSerializer`.
///
/// The serializer exposes exactly these fields. Notably it does NOT return
/// `role` or `is_email_verified`, so the frontend must not branch on either —
/// admin capability is enforced server-side by `IsAdminOrReadOnly`, and
/// verification state is only observable while registering or verifying.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.dateJoined,
  });

  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final DateTime? dateJoined;

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? email : name;
  }

  /// Initials for the avatar chip, falling back to the email local part.
  String get initials {
    final first = firstName.trim();
    final last = lastName.trim();
    if (first.isNotEmpty && last.isNotEmpty) {
      return (first[0] + last[0]).toUpperCase();
    }
    if (first.isNotEmpty) return first[0].toUpperCase();
    final local = email.split('@').first;
    return local.isEmpty ? '?' : local[0].toUpperCase();
  }

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: parseInt(json['id']),
    email: (json['email'] ?? '') as String,
    firstName: (json['first_name'] ?? '') as String,
    lastName: (json['last_name'] ?? '') as String,
    phone: (json['phone'] ?? '') as String,
    dateJoined: parseDate(json['date_joined']),
  );

  /// Only these three are writable; `id`, `email` and `date_joined` are
  /// read-only on the serializer, so sending them back would be ignored.
  Map<String, dynamic> toUpdateJson() => {
    'first_name': firstName,
    'last_name': lastName,
    'phone': phone,
  };

  AppUser copyWith({String? firstName, String? lastName, String? phone}) =>
      AppUser(
        id: id,
        email: email,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        phone: phone ?? this.phone,
        dateJoined: dateJoined,
      );
}
