import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://tictechnologies.in/stage/showmoney/api';

  // ==========================================
  // Comprehensive API Logging Helpers (Using developer.log only)
  // ==========================================
  static void _logRequest({
    required String method,
    required String url,
    Map<String, String>? headers,
    dynamic body,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final buffer = StringBuffer();
    buffer.writeln('\n========================== [API REQUEST START] ==========================');
    buffer.writeln('🌐 METHOD: $method');
    buffer.writeln('🔗 URL: $url');
    buffer.writeln('🕒 TIME: $timestamp');
    if (headers != null && headers.isNotEmpty) {
      buffer.writeln('📋 HEADERS: ${jsonEncode(headers)}');
    }
    if (body != null) {
      buffer.writeln('📦 REQUEST PAYLOAD:');
      try {
        buffer.writeln(const JsonEncoder.withIndent('  ').convert(body));
      } catch (_) {
        buffer.writeln(body.toString());
      }
    }
    buffer.writeln('========================================================================\n');

    developer.log(
      buffer.toString(),
      name: 'ApiService.Request',
      time: DateTime.now(),
    );
  }

  static void _logResponse({
    required String method,
    required String url,
    required int statusCode,
    required int durationMs,
    required String responseBody,
  }) {
    final buffer = StringBuffer();
    final isSuccess = statusCode >= 200 && statusCode < 300;
    final icon = isSuccess ? '✅' : '⚠️';

    buffer.writeln('\n========================== [API RESPONSE START] =========================');
    buffer.writeln('$icon STATUS: $statusCode');
    buffer.writeln('🌐 METHOD: $method');
    buffer.writeln('🔗 URL: $url');
    buffer.writeln('⏱ DURATION: ${durationMs}ms');
    buffer.writeln('📥 RESPONSE BODY:');
    try {
      final decoded = jsonDecode(responseBody);
      buffer.writeln(const JsonEncoder.withIndent('  ').convert(decoded));
    } catch (_) {
      buffer.writeln(responseBody);
    }
    buffer.writeln('========================================================================\n');

    developer.log(
      buffer.toString(),
      name: 'ApiService.Response',
      time: DateTime.now(),
    );
  }

  static void _logError({
    required String method,
    required String url,
    required int durationMs,
    required dynamic error,
    StackTrace? stackTrace,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('\n=========================== [API ERROR START] ===========================');
    buffer.writeln('❌ FAILED: $method $url (⏱ ${durationMs}ms)');
    buffer.writeln('💥 EXCEPTION: $error');
    if (stackTrace != null) {
      buffer.writeln('🔍 STACKTRACE:\n$stackTrace');
    }
    buffer.writeln('========================================================================\n');

    developer.log(
      buffer.toString(),
      name: 'ApiService.Error',
      error: error,
      stackTrace: stackTrace,
      time: DateTime.now(),
    );
  }

  static Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> body) async {
    final url = '$baseUrl/$endpoint';
    final headers = {'Content-Type': 'application/json'};
    final stopwatch = Stopwatch()..start();

    _logRequest(method: 'POST', url: url, headers: headers, body: body);

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );
      stopwatch.stop();

      _logResponse(
        method: 'POST',
        url: url,
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        responseBody: response.body,
      );

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'status': true, 'data': decoded};
    } catch (e, stackTrace) {
      stopwatch.stop();
      _logError(
        method: 'POST',
        url: url,
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _postForm(String endpoint, Map<String, dynamic> body) async {
    final url = '$baseUrl/$endpoint';
    final formBody = body.map((key, value) => MapEntry(key, value?.toString() ?? ''));
    final headers = {'Content-Type': 'application/x-www-form-urlencoded'};
    final stopwatch = Stopwatch()..start();

    _logRequest(method: 'POST (FORM)', url: url, headers: headers, body: formBody);

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: formBody,
      );
      stopwatch.stop();

      _logResponse(
        method: 'POST (FORM)',
        url: url,
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        responseBody: response.body,
      );

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'status': true, 'data': decoded};
    } catch (e, stackTrace) {
      stopwatch.stop();
      _logError(
        method: 'POST (FORM)',
        url: url,
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _get(String endpoint) async {
    final url = '$baseUrl/$endpoint';
    final stopwatch = Stopwatch()..start();

    _logRequest(method: 'GET', url: url);

    try {
      final response = await http.get(Uri.parse(url));
      stopwatch.stop();

      _logResponse(
        method: 'GET',
        url: url,
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        responseBody: response.body,
      );

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'status': true, 'data': decoded};
    } catch (e, stackTrace) {
      stopwatch.stop();
      _logError(
        method: 'GET',
        url: url,
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ==========================================
  // A. Authentication (Unified, Manager, Accounts Login)
  // ==========================================

  /// 1. Unified Login (For Field Executives, Backend Staff, Accounts, Manager)
  /// Endpoint: POST api/login
  static Future<Map<String, dynamic>> login(String email, String password) async {
    developer.log('API [Auth] Unified Login attempt for email: $email', name: 'ApiService.Auth');
    return await _post('login', {'email': email, 'password': password});
  }

  /// 2. Manager Login (group_id = 6)
  /// Endpoint: POST api/manager_login
  static Future<Map<String, dynamic>> managerLogin(String email, String password) async {
    developer.log('API [Auth] Manager Login attempt for email: $email', name: 'ApiService.Auth');
    return await _post('manager_login', {'email': email, 'password': password});
  }

  /// 3. Accounts Login (group_id = 2)
  /// Endpoint: POST api/accounts_login
  static Future<Map<String, dynamic>> accountsLogin(String email, String password) async {
    developer.log('API [Auth] Accounts Login attempt for email: $email', name: 'ApiService.Auth');
    return await _post('accounts_login', {'email': email, 'password': password});
  }

  // ==========================================
  // B. Staff Management (Field Exec, Backend Staff)
  // ==========================================

  /// 1. Create Field Executive & Backend Staff
  /// Endpoint: POST api/create_staff
  /// Allowed group_id: 4 (Field Executive), 5 (Backend Staff)
  static Future<Map<String, dynamic>> createStaff({
    required String name,
    required String email,
    required String password,
    required int groupId,
  }) async {
    developer.log(
      'API [Staff] Create Staff: name=$name, email=$email, group_id=$groupId',
      name: 'ApiService.Staff',
    );
    return await _post('create_staff', {
      'name': name,
      'email': email,
      'password': password,
      'group_id': groupId,
    });
  }

  /// 2. Get Staff List with optional query filters
  /// Endpoint: GET api/get_staff
  /// Optional filters: ?group_id=4, ?group_id=5, ?status=1, ?status=0
  static Future<Map<String, dynamic>> getStaff({int? groupId, int? status}) async {
    developer.log(
      'API [Staff] Get Staff List: group_id=$groupId, status=$status',
      name: 'ApiService.Staff',
    );
    final queryParams = <String>[];
    if (groupId != null) queryParams.add('group_id=$groupId');
    if (status != null) queryParams.add('status=$status');

    final endpoint = queryParams.isNotEmpty
        ? 'get_staff?${queryParams.join('&')}'
        : 'get_staff';

    return await _get(endpoint);
  }

  /// 3. Get Single Staff Details
  /// Endpoint: GET api/get_staff_details?id={id}
  static Future<Map<String, dynamic>> getStaffDetails(int id) async {
    developer.log('API [Staff] Get Staff Details for id=$id', name: 'ApiService.Staff');
    return await _get('get_staff_details?id=$id');
  }

  /// 4. Deactivate / Activate Staff
  /// Endpoint: POST api/update_staff_status (or POST api/deactivate_staff)
  /// status: 0 = Deactivate, 1 = Activate
  static Future<Map<String, dynamic>> updateStaffStatus({
    required int id,
    int? status,
  }) async {
    developer.log(
      'API [Staff] Update Staff Status: id=$id, status=$status',
      name: 'ApiService.Staff',
    );
    final body = <String, dynamic>{'id': id};
    if (status != null) {
      body['status'] = status;
    }
    return await _post('update_staff_status', body);
  }

  /// 5. Update Staff Profile
  /// Endpoint: POST api/update_staff
  static Future<Map<String, dynamic>> updateStaff({
    required int id,
    String? name,
    String? email,
    String? password,
    int? groupId,
    int? status,
  }) async {
    developer.log(
      'API [Staff] Update Staff Profile: id=$id, name=$name, email=$email, group_id=$groupId, status=$status',
      name: 'ApiService.Staff',
    );
    final body = <String, dynamic>{'id': id};
    if (name != null && name.isNotEmpty) body['name'] = name;
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (groupId != null) body['group_id'] = groupId;
    if (status != null) body['status'] = status;

    return await _post('update_staff', body);
  }

  // ==========================================
  // C. Dashboard Stats
  // Endpoint: GET api/dashboard_stats?user_id={id}
  // ==========================================
  static Future<Map<String, dynamic>> getDashboardStats(int userId) async {
    developer.log('API [Dashboard] Get Dashboard Stats for user_id=$userId', name: 'ApiService.Dashboard');
    return await _get('dashboard_stats?user_id=$userId');
  }

  // ==========================================
  // D. Sheet Operations
  // ==========================================

  /// 1. Manager Creates Sheet (Columns configured automatically in backend)
  /// Endpoint: POST api/create_sheet
  static Future<Map<String, dynamic>> createSheet({
    required String title,
    required String description,
    required int createdBy,
    List<Map<String, dynamic>>? leads,
  }) async {
    developer.log(
      'API [Sheets] Create Sheet: title="$title", created_by=$createdBy, leadsCount=${leads?.length ?? 0}',
      name: 'ApiService.Sheets',
    );
    final body = <String, dynamic>{
      'title': title,
      'description': description,
      'created_by': createdBy,
    };
    if (leads != null && leads.isNotEmpty) {
      body['leads'] = leads;
    }
    return await _post('create_sheet', body);
  }

  /// 1.1 Manager see all sheets
  /// Endpoint: POST api/get_all_sheets
  static Future<Map<String, dynamic>> getAllSheets({int? userId}) async {
    developer.log('API [Sheets] POST get_all_sheets (Manager)', name: 'ApiService.Sheets');
    final body = <String, dynamic>{};
    if (userId != null && userId > 0) {
      body['user_id'] = userId;
    }
    return await _post('get_all_sheets', body);
  }

  /// 3.2 Staff Sheet List (Field Executive, Backend Staff, Accounts)
  /// Endpoint: GET api/get_sheets?user_id={id}
  static Future<Map<String, dynamic>> getStaffSheets(int userId) async {
    developer.log('API [Sheets] GET get_sheets for user_id=$userId', name: 'ApiService.Sheets');
    return await _get('get_sheets?user_id=$userId');
  }

  /// Get Sheets for Logged-In User
  /// Manager: POST api/get_all_sheets
  /// Staff / Accounts: GET api/get_sheets?user_id={id}
  static Future<Map<String, dynamic>> getSheets(int userId, [int? groupId, String? role]) async {
    developer.log(
      'API [Sheets] Get Sheets: user_id=$userId, group_id=$groupId, role=$role',
      name: 'ApiService.Sheets',
    );
    final isManager = (groupId != null && (groupId == 6 || groupId == 1)) ||
        (role != null && (role.toLowerCase().contains('manager') || role.toLowerCase().contains('admin')));

    if (isManager) {
      try {
        final res = await getAllSheets(userId: userId);
        if (res['status'] == true && res['data'] != null) {
          return res;
        }
      } catch (e) {
        developer.log('API [Sheets] get_all_sheets fallback to get_sheets: $e', name: 'ApiService.Sheets');
      }
    }
    return await getStaffSheets(userId);
  }

  /// 1.2 & 3.3 & 5.2 To see sheets separately (Role-Filtered, for all users)
  /// Endpoint: POST api/sheet_details
  /// Request Body: sheet_id, user_id, role (Accounts / Feild Executive / BackEnd Staff / Manager)
  static Future<Map<String, dynamic>> getSheetDetails({
    required int sheetId,
    required int userId,
    String? role,
  }) async {
    developer.log(
      'API [Sheets] POST sheet_details: sheet_id=$sheetId, user_id=$userId, role=$role',
      name: 'ApiService.Sheets',
    );
    final body = <String, dynamic>{
      'sheet_id': sheetId,
      'user_id': userId,
    };
    if (role != null && role.isNotEmpty) {
      body['role'] = role;
    }

    // CodeIgniter endpoint reads $_POST and requires application/x-www-form-urlencoded
    final res = await _postForm('sheet_details', body);
    if (res['status'] == true) {
      return res;
    }

    // Fallback to application/json in case backend changes in future
    try {
      final jsonRes = await _post('sheet_details', body);
      if (jsonRes['status'] == true) {
        return jsonRes;
      }
    } catch (_) {}

    return res;
  }

  /// 1.3 Add Row / Lead to Sheet (Manager)
  /// Endpoint: POST api/add_row
  static Future<Map<String, dynamic>> addRow({
    required int sheetId,
    required int createdBy,
    int? assignedTo,
    String status = 'new',
    required Map<String, dynamic> data,
  }) async {
    developer.log(
      'API [Rows] Add Row: sheet_id=$sheetId, created_by=$createdBy, assigned_to=$assignedTo',
      name: 'ApiService.Rows',
    );
    final body = <String, dynamic>{
      'sheet_id': sheetId,
      'created_by': createdBy,
      'status': status,
      'data': data,
    };
    if (assignedTo != null && assignedTo > 0) {
      body['assigned_to'] = assignedTo;
    }
    return await _post('add_row', body);
  }

  /// 4. Assign Sheet to Field Executive or Office Executive
  /// Endpoint: POST api/assign_sheet (or api/assign_to_staff)
  static Future<Map<String, dynamic>> assignSheetToStaff({
    required int sheetId,
    required int userId,
    required int assignedBy,
  }) async {
    developer.log(
      'API [Sheets] Assign Sheet to Staff: sheet_id=$sheetId, staff_user_id=$userId, assigned_by=$assignedBy',
      name: 'ApiService.Sheets',
    );
    return await _post('assign_sheet', {
      'sheet_id': sheetId,
      'user_id': userId,
      'assigned_by': assignedBy,
    });
  }

  /// 5. Assign Sheet to Accounts
  /// Endpoint: POST api/assign_to_accounts
  /// Request Body: sheet_id, accounts_user_id, assigned_by
  static Future<Map<String, dynamic>> assignSheetToAccounts({
    required int sheetId,
    required int accountsUserId,
    required int assignedBy,
  }) async {
    developer.log(
      'API [Sheets] Assign Sheet to Accounts: sheet_id=$sheetId, accounts_user_id=$accountsUserId, assigned_by=$assignedBy',
      name: 'ApiService.Sheets',
    );
    return await _post('assign_to_accounts', {
      'sheet_id': sheetId,
      'accounts_user_id': accountsUserId,
      'user_id': accountsUserId,
      'assigned_by': assignedBy,
    });
  }

  /// 1.4 & 3.4 & 5.3 Update Row Fields & Status (for all users)
  /// Endpoint: POST api/update_row
  /// Body: action="update_row", row_id, role, data, status
  static Future<Map<String, dynamic>> updateRow({
    required int rowId,
    required Map<String, dynamic> data,
    String? status,
    String? role,
  }) async {
    developer.log(
      'API [Rows] Update Row: row_id=$rowId, role=$role, status=$status',
      name: 'ApiService.Rows',
    );
    final body = <String, dynamic>{
      'action': 'update_row',
      'row_id': rowId,
      'data': data,
    };
    if (status != null && status.isNotEmpty) {
      body['status'] = status;
    }
    if (role != null && role.isNotEmpty) {
      body['role'] = role;
    }
    return await _post('update_row', body);
  }

  /// Single Cell Update (for direct Excel inline grid editing)
  static Future<Map<String, dynamic>> updateCell({
    required int rowId,
    required String columnKey,
    required String value,
    int? sheetId,
    int? createdBy,
    int? assignedTo,
  }) async {
    developer.log(
      'API [Rows] Update Cell: row_id=$rowId, column_key=$columnKey, value="$value"',
      name: 'ApiService.Rows',
    );
    final body = <String, dynamic>{
      'row_id': rowId,
      'column_key': columnKey,
      'value': value,
    };
    if (rowId == 0) {
      if (sheetId != null) body['sheet_id'] = sheetId;
      if (createdBy != null) body['created_by'] = createdBy;
      if (assignedTo != null) body['assigned_to'] = assignedTo;
    }
    return await _post('update_cell', body);
  }

  static Future<Map<String, dynamic>> updateRowStatus({
    required int rowId,
    required String status,
  }) async {
    developer.log(
      'API [Rows] Update Row Status: row_id=$rowId, status=$status',
      name: 'ApiService.Rows',
    );
    return await _post('update_row_status', {
      'row_id': rowId,
      'status': status,
    });
  }

  static Future<Map<String, dynamic>> updateColumn({
    required int columnId,
    required String columnName,
  }) async {
    developer.log(
      'API [Columns] Update Column: column_id=$columnId, column_name="$columnName"',
      name: 'ApiService.Columns',
    );
    return await _post('update_column', {
      'column_id': columnId,
      'column_name': columnName,
    });
  }

  static Future<Map<String, dynamic>> addColumn({
    required int sheetId,
    required String columnName,
    required String columnType,
    List<String>? options,
  }) async {
    developer.log(
      'API [Columns] Add Column: sheet_id=$sheetId, column_name="$columnName", type=$columnType',
      name: 'ApiService.Columns',
    );
    final body = <String, dynamic>{
      'sheet_id': sheetId,
      'column_name': columnName,
      'column_type': columnType,
    };
    if (options != null && options.isNotEmpty) {
      body['options'] = options;
    }
    return await _post('add_column', body);
  }

  static Future<Map<String, dynamic>> shareSheet({
    required int sheetId,
    required List<int> userIds,
    required int assignedBy,
    required String role,
  }) async {
    developer.log(
      'API [Sheets] Share Sheet: sheet_id=$sheetId, user_ids=$userIds, role=$role',
      name: 'ApiService.Sheets',
    );
    return await _post('share_sheet', {
      'sheet_id': sheetId,
      'user_ids': userIds,
      'assigned_by': assignedBy,
      'role': role,
    });
  }
}
