import 'package:flutter/foundation.dart';

import '../core/network/api_exception.dart';
import '../models/address.dart';
import '../services/account_service.dart';

/// Owns the customer's single shipping address.
class AccountProvider extends ChangeNotifier {
  AccountProvider(this._service);

  final AccountService _service;

  Address? _address;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  Address? get address => _address;
  bool get hasAddress => _address != null;
  bool get isLoading => _loading;
  bool get isSaving => _saving;
  String? get error => _error;
  Map<String, String> get fieldErrors => _fieldErrors;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _address = await _service.fetchAddress();
    } on ApiException catch (error) {
      // 401 is expected when signed out; the UI gates on auth separately.
      if (!error.isUnauthorized) _error = error.message;
      _address = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void reset() {
    _address = null;
    _error = null;
    _fieldErrors = const {};
    notifyListeners();
  }

  /// Creates or updates, depending on whether one already exists.
  Future<bool> save(Address address) async {
    _saving = true;
    _error = null;
    _fieldErrors = const {};
    notifyListeners();

    try {
      _address = await _service.saveAddress(
        address.id == 0 && _address != null
            // Reuse the existing id so a re-save updates instead of hitting
            // the serializer's "You already have an address." guard.
            ? Address(
                id: _address!.id,
                firstName: address.firstName,
                lastName: address.lastName,
                company: address.company,
                address1: address.address1,
                address2: address.address2,
                city: address.city,
                postalCode: address.postalCode,
                country: address.country,
                region: address.region,
              )
            : address,
      );
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      _fieldErrors = error.fieldErrors;
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> delete() async {
    final current = _address;
    if (current == null) return true;

    _saving = true;
    notifyListeners();

    try {
      await _service.deleteAddress(current.id);
      _address = null;
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
