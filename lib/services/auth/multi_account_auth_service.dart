import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:eisenvaultappflutter/models/account.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Service to manage multiple logged-in accounts
/// Stores accounts securely and allows switching between them
class MultiAccountAuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _accountsKey = 'multi_accounts';
  static const String _activeAccountIdKey = 'active_account_id';

  /// Get all stored accounts
  Future<List<Account>> getAllAccounts() async {
    try {
      final accountsJson = await _storage.read(key: _accountsKey);
      if (accountsJson == null || accountsJson.isEmpty) {
        return [];
      }

      final List<dynamic> decoded = json.decode(accountsJson);
      return decoded.map((json) => Account.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      EVLogger.error('Failed to get all accounts', e);
      return [];
    }
  }

  /// Get the currently active account ID
  Future<String?> getActiveAccountId() async {
    try {
      return await _storage.read(key: _activeAccountIdKey);
    } catch (e) {
      EVLogger.error('Failed to get active account ID', e);
      return null;
    }
  }

  /// Get the active account
  Future<Account?> getActiveAccount() async {
    try {
      final activeId = await getActiveAccountId();
      if (activeId == null) return null;

      final accounts = await getAllAccounts();
      return accounts.firstWhere(
        (account) => account.id == activeId,
        orElse: () => throw StateError('Active account not found'),
      );
    } catch (e) {
      EVLogger.error('Failed to get active account', e);
      return null;
    }
  }

  /// Add or update an account
  /// If account with same ID exists, it will be updated
  Future<bool> addOrUpdateAccount(Account account) async {
    try {
      final accounts = await getAllAccounts();
      
      // Remove existing account with same ID if it exists
      accounts.removeWhere((a) => a.id == account.id);
      
      // Add the new/updated account
      accounts.add(account);
      
      // Sort by lastUsed (most recent first)
      accounts.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
      
      // Save accounts
      final accountsJson = json.encode(accounts.map((a) => a.toJson()).toList());
      await _storage.write(key: _accountsKey, value: accountsJson);
      
      // If this is the first account or no active account is set, make it active
      final activeId = await getActiveAccountId();
      if (activeId == null || accounts.length == 1) {
        await setActiveAccount(account.id);
      }
      
      return true;
    } catch (e) {
      EVLogger.error('Failed to add/update account', e);
      return false;
    }
  }

  /// Remove an account
  Future<bool> removeAccount(String accountId) async {
    try {
      final accounts = await getAllAccounts();
      final initialLength = accounts.length;
      accounts.removeWhere((a) => a.id == accountId);
      final removed = accounts.length < initialLength;
      
      if (!removed) {
        return false;
      }
      
      // Save updated accounts list
      final accountsJson = json.encode(accounts.map((a) => a.toJson()).toList());
      await _storage.write(key: _accountsKey, value: accountsJson);
      
      // If we removed the active account, set a new active account
      final activeId = await getActiveAccountId();
      if (activeId == accountId) {
        if (accounts.isNotEmpty) {
          // Set the most recently used account as active
          await setActiveAccount(accounts.first.id);
        } else {
          // No accounts left, clear active account
          await _storage.delete(key: _activeAccountIdKey);
        }
      }
      
      return true;
    } catch (e) {
      EVLogger.error('Failed to remove account', e);
      return false;
    }
  }

  /// Set the active account
  Future<bool> setActiveAccount(String accountId) async {
    try {
      // Verify account exists
      final accounts = await getAllAccounts();
      if (!accounts.any((a) => a.id == accountId)) {
        EVLogger.warning('Cannot set active account: account not found', {'accountId': accountId});
        return false;
      }
      
      // Update lastUsed for the account being activated
      final account = accounts.firstWhere((a) => a.id == accountId);
      final updatedAccount = account.copyWith(lastUsed: DateTime.now());
      accounts.removeWhere((a) => a.id == accountId);
      accounts.add(updatedAccount);
      accounts.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
      
      // Save updated accounts
      final accountsJson = json.encode(accounts.map((a) => a.toJson()).toList());
      await _storage.write(key: _accountsKey, value: accountsJson);
      
      // Set as active
      await _storage.write(key: _activeAccountIdKey, value: accountId);
      
      return true;
    } catch (e) {
      EVLogger.error('Failed to set active account', e);
      return false;
    }
  }

  /// Update account token (for token refresh)
  Future<bool> updateAccountToken(String accountId, String newToken, {String? tokenExpiry}) async {
    try {
      final accounts = await getAllAccounts();
      final accountIndex = accounts.indexWhere((a) => a.id == accountId);
      
      if (accountIndex == -1) {
        EVLogger.warning('Cannot update token: account not found', {'accountId': accountId});
        return false;
      }
      
      final account = accounts[accountIndex];
      final updatedAccount = account.copyWith(
        token: newToken,
        tokenExpiry: tokenExpiry ?? account.tokenExpiry,
      );
      
      accounts[accountIndex] = updatedAccount;
      
      // Save updated accounts
      final accountsJson = json.encode(accounts.map((a) => a.toJson()).toList());
      await _storage.write(key: _accountsKey, value: accountsJson);
      
      return true;
    } catch (e) {
      EVLogger.error('Failed to update account token', e);
      return false;
    }
  }

  /// Clear all accounts (for logout all)
  Future<bool> clearAllAccounts() async {
    try {
      await _storage.delete(key: _accountsKey);
      await _storage.delete(key: _activeAccountIdKey);
      return true;
    } catch (e) {
      EVLogger.error('Failed to clear all accounts', e);
      return false;
    }
  }

  /// Check if any accounts exist
  Future<bool> hasAccounts() async {
    final accounts = await getAllAccounts();
    return accounts.isNotEmpty;
  }
}

