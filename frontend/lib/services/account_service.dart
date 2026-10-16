import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/address.dart';
import '../models/paginated.dart';

/// Wraps the address half of the `accounts` API.
///
/// `Address.user` is a OneToOneField, so the list endpoint returns either zero
/// or one entry for the signed-in customer and `create` 400s on a second
/// attempt. [save] therefore picks POST or PATCH based on what already exists.
class AccountService {
  AccountService(this._client);

  final ApiClient _client;

  Future<Address?> fetchAddress() async {
    final data = await _client.get<dynamic>(ApiEndpoints.addresses);
    final page = Paginated.fromAny<Address>(data, Address.fromJson);
    return page.items.isEmpty ? null : page.items.first;
  }

  Future<Address> createAddress(Address address) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.addresses,
      body: address.toJson(),
    );
    return Address.fromJson(data);
  }

  Future<Address> updateAddress(int id, Address address) async {
    final data = await _client.patch<Map<String, dynamic>>(
      ApiEndpoints.address(id),
      body: address.toJson(),
    );
    return Address.fromJson(data);
  }

  /// Creates or updates in one call, so the UI needs a single "Save" action.
  Future<Address> saveAddress(Address address) => address.id == 0
      ? createAddress(address)
      : updateAddress(address.id, address);

  Future<void> deleteAddress(int id) =>
      _client.delete(ApiEndpoints.address(id));
}
