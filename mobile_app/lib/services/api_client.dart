import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config/api_config.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class AuthUser {
  const AuthUser({required this.username, required this.role});
  final String username;
  final String role;
  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        username: '${json['username'] ?? 'User'}',
        role: '${json['role'] ?? 'Operator'}',
      );
}

class ApiClient {
  ApiClient({String? baseUrl})
      : baseUrl = (baseUrl ?? apiBaseUrl).replaceAll(RegExp(r'/$'), '');
  final String baseUrl;
  static const _storage = FlutterSecureStorage();
  String? _token;
  String? get token => _token;

  Future<AuthUser> signIn(String identity, String password) async {
    final data = await _request('POST', '/api/auth/login',
        body: {
          'identity': identity.trim(),
          'password': password,
          'remember': true,
        },
        authenticated: false);
    final token = '${data['token'] ?? ''}';
    if (token.isEmpty) {
      throw const ApiException('The server did not return a session token.');
    }
    _token = token;
    await _storage.write(key: 'forgewatch_api_token', value: token);
    return AuthUser(
        username: '${data['username'] ?? identity}',
        role: '${data['role'] ?? 'Operator'}');
  }

  Future<AuthUser?> restoreSession() async {
    _token = await _storage.read(key: 'forgewatch_api_token');
    if (_token == null || _token!.isEmpty) return null;
    try {
      return AuthUser.fromJson(await get('/api/auth/me'));
    } on ApiException catch (e) {
      if (e.statusCode == 401) await signOut();
      rethrow;
    }
  }

  Future<void> register(String username, String password) async {
    await _request('POST', '/api/auth/register',
        body: {'username': username.trim(), 'password': password},
        authenticated: false);
  }

  Future<void> signOut() async {
    try {
      if (_token != null) {
        await _request('POST', '/api/auth/logout',
            body: const {},
            authenticated: true,
            timeout: const Duration(seconds: 4));
      }
    } catch (_) {
      // Always clear local credentials, including while offline.
    } finally {
      _token = null;
      await _storage.delete(key: 'forgewatch_api_token');
    }
  }

  Future<Map<String, dynamic>> get(String path,
          {Map<String, String>? query}) async =>
      await _request('GET', path, query: query) as Map<String, dynamic>;
  Future<Map<String, dynamic>> post(String path,
          [Map<String, dynamic>? body]) async =>
      await _request('POST', path, body: body ?? const {})
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> patch(
          String path, Map<String, dynamic> body) async =>
      await _request('PATCH', path, body: body) as Map<String, dynamic>;

  Future<dynamic> getList(String path, {Map<String, String>? query}) async =>
      _request('GET', path, query: query, allowList: true);

  Future<dynamic> _request(String method, String path,
      {Map<String, dynamic>? body,
      Map<String, String>? query,
      bool authenticated = true,
      bool allowList = false,
      Duration timeout = const Duration(seconds: 60)}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (authenticated && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await request.send().timeout(timeout);
      response = await http.Response.fromStream(streamed).timeout(timeout);
    } on SocketException {
      throw const ApiException(
          'No connection to FORGEWATCH. Check Wi-Fi or mobile data, then try again.');
    } on HttpException {
      throw const ApiException(
          'Could not reach the FORGEWATCH server. Check your internet connection.');
    } on FormatException {
      throw const ApiException(
          'The API address is invalid. Check the selected app environment.');
    } on Exception catch (e) {
      if (e is ApiException) rethrow;
      throw const ApiException(
          'The request timed out. Check your connection and try again.');
    }
    dynamic decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } on FormatException {
      decoded = <String, dynamic>{};
    }
    if (response.statusCode == 401) {
      throw const ApiException('Your session expired. Sign in again.',
          statusCode: 401);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          decoded is Map ? decoded['error'] ?? decoded['message'] : null;
      throw ApiException(
          message?.toString() ??
              'Server request failed (${response.statusCode}).',
          statusCode: response.statusCode);
    }
    if (allowList) return decoded is List ? decoded : <dynamic>[];
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is List) return <String, dynamic>{'items': decoded};
    return <String, dynamic>{};
  }

  Future<void> downloadAndShare(
      String path, String filename, String mimeType) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer ${_token ?? ''}'
      }).timeout(const Duration(seconds: 25));
      if (response.statusCode == 401) {
        throw const ApiException('Your session expired. Sign in again.',
            statusCode: 401);
      }
      if (response.statusCode != 200) {
        throw ApiException('Report generation failed (${response.statusCode}).',
            statusCode: response.statusCode);
      }
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      await Share.shareXFiles([XFile(file.path, mimeType: mimeType)],
          text: 'FORGEWATCH simulated machine report');
    } on SocketException {
      throw const ApiException(
          'No internet connection. Reports need the online FORGEWATCH backend.');
    } on ApiException {
      rethrow;
    } on Exception {
      throw const ApiException(
          'Could not download or share this report. Please try again.');
    }
  }
}
