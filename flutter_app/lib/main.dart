import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _brand = Color(0xFF1769F5);
const _brandDeep = Color(0xFF104DDD);
const _ink = Color(0xFF18233B);
const _muted = Color(0xFF64748B);
const _line = Color(0xFFE0E9F6);
const _canvas = Color(0xFFF3F8FF);
const _apiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);

void main() => runApp(const UserManagementApp());

class UserManagementApp extends StatelessWidget {
  const UserManagementApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Quản lý người dùng',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _brand,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: _canvas,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 19, color: _ink, height: 1.35),
        bodyMedium: TextStyle(fontSize: 19, color: _ink, height: 1.35),
        bodySmall: TextStyle(fontSize: 17, color: _muted),
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
        titleMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
        labelLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          foregroundColor: _brandDeep,
          side: const BorderSide(color: _line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _brandDeep,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 19),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: _line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: _brand, width: 1.5),
        ),
      ),
    ),
    home: const UserManagementHome(),
  );
}

class UserManagementHome extends StatefulWidget {
  const UserManagementHome({super.key});

  @override
  State<UserManagementHome> createState() => _UserManagementHomeState();
}

class _UserManagementHomeState extends State<UserManagementHome> {
  final _picker = ImagePicker();
  final _authKey = GlobalKey<FormState>();
  final _userKey = GlobalKey<FormState>();
  final _authName = TextEditingController();
  final _authEmail = TextEditingController();
  final _authPassword = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _currentPassword = TextEditingController();
  final _imageUrl = TextEditingController();
  final _search = TextEditingController();

  String? _token;
  Map<String, dynamic>? _me;
  List<Map<String, dynamic>> _users = [];
  String _imageData = '';
  String? _editingId;
  String? _error;
  int _dashboardTab = 0;
  bool _editingProfile = false;
  bool _registering = false;
  bool _loading = true;
  bool _saving = false;
  int _avatarFilter = 0;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _restoreSession();
  }

  @override
  void dispose() {
    _authName.dispose();
    _authEmail.dispose();
    _authPassword.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _currentPassword.dispose();
    _imageUrl.dispose();
    _search.dispose();
    super.dispose();
  }

  Uri _uri(String path) => Uri.parse('$_apiBase$path');

  Future<dynamic> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final headers = <String, String>{
      if (body != null) 'Content-Type': 'application/json',
      if (authenticated && _token != null) 'Authorization': 'Bearer $_token',
    };
    late http.Response response;
    try {
      final request = http.Request(method, _uri(path))..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      response = await http.Response.fromStream(await request.send());
    } catch (_) {
      throw Exception(
        'Không kết nối được backend tại $_apiBase. Hãy kiểm tra server và API_BASE_URL.',
      );
    }
    final dynamic decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map ? decoded['message']?.toString() : null;
      throw Exception(message ?? 'Lỗi máy chủ (${response.statusCode})');
    }
    return decoded;
  }

  Future<void> _restoreSession() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = preferences.getString('user_management_token');
      if (stored != null && stored.isNotEmpty) {
        _token = stored;
        final response = await _request('/api/users/me');
        _me = Map<String, dynamic>.from(response['user'] as Map);
        await _loadUsers();
      }
    } catch (_) {
      await _clearSession();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearSession() async {
    _token = null;
    _me = null;
    _users = [];
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('user_management_token');
  }

  Future<void> _loadUsers() async {
    final response = await _request('/api/users');
    if (response is! List) {
      throw Exception('Backend trả về danh sách không hợp lệ.');
    }
    _users = response
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    if (mounted) setState(() {});
  }

  Future<void> _submitAuth() async {
    if (!_authKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final email = _authEmail.text.trim();
      final password = _authPassword.text;
      if (_registering) {
        await _request(
          '/api/users',
          method: 'POST',
          authenticated: false,
          body: {
            'email': email,
            'matkhau': password,
            'hoten': _authName.text.trim(),
          },
        );
      }
      final response = await _request(
        '/api/users/login',
        method: 'POST',
        authenticated: false,
        body: {'email': email, 'matkhau': password},
      );
      _token = response['token'] as String;
      _me = Map<String, dynamic>.from(response['user'] as Map);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('user_management_token', _token!);
      await _loadUsers();
      _authName.clear();
      _authEmail.clear();
      _authPassword.clear();
    } catch (error) {
      _error = _message(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  Future<void> _logout() async {
    await _clearSession();
    if (mounted) {
      setState(() {
        _error = null;
        _resetForm();
      });
    }
  }

  Future<void> _pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 60,
        maxWidth: 960,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        setState(() => _error = 'Ảnh lớn hơn 2 MB. Hãy chọn ảnh khác.');
        return;
      }
      final mime = picked.mimeType ?? 'image/jpeg';
      setState(() {
        _imageData = 'data:$mime;base64,${base64Encode(bytes)}';
        _imageUrl.clear();
        _error = null;
      });
    } catch (error) {
      setState(() => _error = 'Không thể mở ảnh: ${_message(error)}');
    }
  }

  void _editUser(Map<String, dynamic> user, {bool profile = false}) {
    setState(() {
      _dashboardTab = profile ? 2 : 1;
      _editingProfile = profile;
      _editingId = (user['id'] ?? user['_id']).toString();
      _name.text = user['hoten']?.toString() ?? '';
      _email.text = user['email']?.toString() ?? '';
      _password.clear();
      _currentPassword.clear();
      final image = user['hinhanh']?.toString() ?? '';
      if (image.startsWith('data:')) {
        _imageData = image;
        _imageUrl.clear();
      } else {
        _imageData = '';
        _imageUrl.text = image;
      }
      _error = null;
    });
  }

  void _startNewUser() {
    setState(() {
      _resetForm();
      _dashboardTab = 1;
      _editingProfile = false;
      _error = null;
    });
  }

  void _resetForm() {
    _editingId = null;
    _editingProfile = false;
    _imageData = '';
    _name.clear();
    _email.clear();
    _password.clear();
    _currentPassword.clear();
    _imageUrl.clear();
  }

  Future<void> _saveUser() async {
    if (!_userKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final isEditing = _editingId != null;
    final isEditingProfile = _editingProfile;
    final body = <String, dynamic>{
      'hoten': _name.text.trim(),
      'email': _email.text.trim(),
      'hinhanh': _imageData.isNotEmpty ? _imageData : _imageUrl.text.trim(),
    };
    if (_password.text.isNotEmpty) {
      body['matkhau'] = _password.text;
      if (_editingProfile) body['matkhauCu'] = _currentPassword.text;
    }
    try {
      final response = await _request(
        isEditing
            ? '/api/users/${Uri.encodeComponent(_editingId!)}'
            : '/api/users',
        method: isEditing ? 'PUT' : 'POST',
        body: body,
      );
      _resetForm();
      _dashboardTab = isEditingProfile ? 2 : 0;
      if (isEditing &&
          (response['user']['id'] == (_me?['id'] ?? _me?['_id']))) {
        _me = Map<String, dynamic>.from(response['user'] as Map);
      }
      await _loadUsers();
      if (mounted) {
        _snack(isEditing ? 'Đã cập nhật người dùng' : 'Đã thêm người dùng');
      }
    } catch (error) {
      setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa người dùng?'),
        content: Text('Bạn muốn xóa tài khoản ${user['email']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final id = (user['id'] ?? user['_id']).toString();
      await _request('/api/users/${Uri.encodeComponent(id)}', method: 'DELETE');
      if (_editingId == id) {
        _resetForm();
        _dashboardTab = 0;
      }
      await _loadUsers();
      if (mounted) _snack('Đã xóa người dùng');
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _showPasswordHelp() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.support_agent_rounded, color: _brand),
      title: const Text('Cấp lại mật khẩu'),
      content: const Text(
        'Để bảo vệ tài khoản, ứng dụng chưa tự đặt lại mật khẩu qua email. '
        'Vui lòng liên hệ quản trị viên để xác minh danh tính và được hỗ trợ. '
        'Nếu bạn vẫn đăng nhập được, hãy mở mục Tài khoản để đổi mật khẩu.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đã hiểu'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_token == null) return _buildAuth();
    return _buildDashboard();
  }

  Widget _buildAuth() => Scaffold(
    body: CustomPaint(
      painter: const _DotPainter(),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE6F1FF), Color(0xFFFFFFFF)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 850;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 36 : 20,
                    vertical: 28,
                  ),
                  child: wide
                      ? Row(
                          children: [
                            Expanded(child: _intro()),
                            const SizedBox(width: 52),
                            SizedBox(width: 480, child: _authCard()),
                          ],
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _intro(compact: true),
                              const SizedBox(height: 28),
                              _authCard(),
                            ],
                          ),
                        ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _intro({bool compact = false}) => Column(
    mainAxisAlignment: compact
        ? MainAxisAlignment.start
        : MainAxisAlignment.center,
    crossAxisAlignment: compact
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: compact
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Container(
            width: compact ? 48 : 42,
            height: compact ? 48 : 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_brand, _brandDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Center(
              child: Icon(Icons.shield_rounded, color: Colors.white, size: 27),
            ),
          ),
          const SizedBox(width: 11),
          const Text(
            'Nova',
            style: TextStyle(
              color: _ink,
              fontSize: 27,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Text(
            'ID',
            style: TextStyle(
              color: _brand,
              fontSize: 27,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      SizedBox(height: compact ? 25 : 56),
      const _Kicker('CHÀO MỪNG ĐẾN VỚI NOVAID'),
      const SizedBox(height: 14),
      Text(
        compact
            ? 'Kết nối mọi người,\nquản lý dễ dàng.'
            : 'Kết nối mọi người,\nquản lý dễ dàng.',
        style: TextStyle(
          fontSize: compact ? 32 : 44,
          height: 1.16,
          color: _ink,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.4,
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'Không gian quản lý thành viên hiện đại, kết nối và cá nhân hóa theo cách của bạn.',
        style: TextStyle(color: _muted, fontSize: 19, height: 1.7),
      ),
      if (!compact) ...[
        const SizedBox(height: 30),
        const _Feature(text: 'Dữ liệu lưu trữ an toàn trong MongoDB'),
        const _Feature(text: 'Mật khẩu được mã hóa trước khi lưu'),
        const _Feature(text: 'Giao diện tương thích với điện thoại'),
      ],
    ],
  );

  Widget _authCard() => _Card(
    padding: const EdgeInsets.all(26),
    radius: 28,
    child: Form(
      key: _authKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AuthTab(
                label: 'Đăng nhập',
                active: !_registering,
                onTap: () => setState(() {
                  _registering = false;
                  _error = null;
                }),
              ),
              const SizedBox(width: 22),
              _AuthTab(
                label: 'Tạo tài khoản',
                active: _registering,
                onTap: () => setState(() {
                  _registering = true;
                  _error = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            _registering ? 'Tham gia NovaID ✨' : 'Chào mừng trở lại 👋',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _registering
                ? 'Tạo tài khoản để bắt đầu sử dụng.'
                : 'Đăng nhập để khám phá không gian của bạn.',
            style: const TextStyle(color: _muted, fontSize: 17),
          ),
          const SizedBox(height: 23),
          if (_registering) ...[
            _Field(
              label: 'Họ và tên',
              controller: _authName,
              hint: 'Nguyễn Văn A',
              validator: _required,
            ),
            const SizedBox(height: 14),
          ],
          _Field(
            label: 'Email',
            controller: _authEmail,
            hint: 'ban@example.com',
            keyboardType: TextInputType.emailAddress,
            large: true,
            validator: _emailValidator,
          ),
          const SizedBox(height: 14),
          _Field(
            label: 'Mật khẩu',
            controller: _authPassword,
            hint: 'Ít nhất 6 ký tự',
            obscure: true,
            large: true,
            showPasswordToggle: true,
            validator: _passwordValidator,
          ),
          const SizedBox(height: 8),
          if (_error != null) _ErrorText(_error!),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _saving ? null : _submitAuth,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_registering ? 'Tạo tài khoản' : 'Đăng nhập'),
            ),
          ),
          if (!_registering) ...[
            const SizedBox(height: 14),
            Center(
              child: TextButton.icon(
                onPressed: _showPasswordHelp,
                icon: const Icon(Icons.lock_reset_rounded, size: 18),
                label: const Text('Quên mật khẩu?'),
                style: TextButton.styleFrom(
                  foregroundColor: _brandDeep,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _buildDashboard() {
    final isWide = MediaQuery.sizeOf(context).width >= 860;
    final formMinHeight =
        (MediaQuery.sizeOf(context).height -
                kToolbarHeight -
                (isWide ? 70 : 140))
            .clamp(360.0, double.infinity);
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_brand, _brandDeep]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text(
              'NovaID',
              style: TextStyle(
                color: _ink,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          if (isWide && _me != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  _me!['email'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 16),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: CustomPaint(
        painter: const _DotPainter(),
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: double.infinity),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  constraints.maxWidth >= 860 ? 28 : 16,
                  22,
                  constraints.maxWidth >= 860 ? 28 : 16,
                  12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_me != null) ...[
                      _signedInUserCard(),
                      const SizedBox(height: 16),
                    ],
                    if (isWide) ...[
                      _dashboardTabs(),
                      const SizedBox(height: 24),
                    ],
                    Expanded(
                      child: switch (_dashboardTab) {
                        0 => _userListPage(),
                        1 => SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: double.infinity,
                                minHeight: formMinHeight,
                              ),
                              child: _userForm(),
                            ),
                          ),
                        ),
                        _ =>
                          !_editingProfile
                              ? _profilePage()
                              : SingleChildScrollView(
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: double.infinity,
                                        minHeight: formMinHeight,
                                      ),
                                      child: _userForm(),
                                    ),
                                  ),
                                ),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              height: 76,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              indicatorColor: const Color(0xFFE6F1FF),
              selectedIndex: _dashboardTab,
              onDestinationSelected: _selectDashboardTab,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: 'Thành viên',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_add_alt_outlined),
                  selectedIcon: Icon(Icons.person_add_alt),
                  label: 'Thêm mới',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_circle_outlined),
                  selectedIcon: Icon(Icons.account_circle),
                  label: 'Tài khoản',
                ),
              ],
            ),
    );
  }

  Widget _signedInUserCard() {
    final user = _me!;
    final compact = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Semantics(
      container: true,
      child: Material(
        color: const Color(0xFFE7F0FF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFCCDFFF)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _selectDashboardTab(2),
          child: Padding(
            padding: EdgeInsets.all(compact ? 10 : 16),
            child: Row(
              children: [
                _Avatar(
                  value: user['hinhanh']?.toString() ?? '',
                  name: user['hoten']?.toString() ?? '',
                  size: compact ? 42 : 54,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!compact) ...[
                        const Text(
                          'Đang đăng nhập',
                          style: TextStyle(
                            color: _brandDeep,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        user['hoten']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user['email']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: _brandDeep),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectDashboardTab(int index) {
    if (index == 1) {
      _startNewUser();
      return;
    }
    if (index == 2 && _me != null) {
      setState(() {
        _resetForm();
        _dashboardTab = 2;
        _error = null;
      });
      return;
    }
    setState(() {
      _dashboardTab = index;
      _error = null;
    });
  }

  Widget _dashboardTabs() => Row(
    children: [
      _DashboardTab(
        icon: Icons.people_outline,
        label: 'Thành viên',
        active: _dashboardTab == 0,
        onTap: () => _selectDashboardTab(0),
      ),
      const SizedBox(width: 10),
      _DashboardTab(
        icon: Icons.person_add_alt_outlined,
        label: 'Thêm thành viên',
        active: _dashboardTab == 1,
        onTap: _startNewUser,
      ),
      const SizedBox(width: 10),
      _DashboardTab(
        icon: Icons.account_circle_outlined,
        label: 'Tài khoản',
        active: _dashboardTab == 2,
        onTap: () => _selectDashboardTab(2),
      ),
    ],
  );

  Widget _userListPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Kicker('CỘNG ĐỒNG NOVAID'),
                SizedBox(height: 4),
                Text(
                  'Thành viên',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Khám phá và kết nối các thành viên',
                  style: TextStyle(color: _muted, fontSize: 16),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _startNewUser,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Thêm mới'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 13),
            ),
          ),
        ],
      ),
      const SizedBox(height: 13),
      Row(
        children: [
          Expanded(
            child: _SummaryCard(
              label: 'Tổng thành viên',
              value: '${_users.length}',
              icon: Icons.groups_2_outlined,
              color: _brand,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _SummaryCard(
              label: 'Có ảnh đại diện',
              value:
                  '${_users.where((user) => (user['hinhanh'] ?? '').toString().isNotEmpty).length}',
              icon: Icons.photo_camera_back_outlined,
              color: const Color(0xFF4599F8),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Expanded(child: _userList()),
    ],
  );

  Widget _userForm() => _Card(
    child: Form(
      key: _userKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Kicker(
                      _editingId == null
                          ? 'TÀI KHOẢN MỚI'
                          : _editingProfile
                          ? 'CHỈNH SỬA HỒ SƠ'
                          : 'CHỈNH SỬA THÀNH VIÊN',
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _editingId == null
                          ? 'Thêm người dùng'
                          : _editingProfile
                          ? 'Cập nhật hồ sơ'
                          : 'Cập nhật người dùng',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (_editingId != null)
                TextButton(
                  onPressed: () => setState(() {
                    _resetForm();
                    _dashboardTab = 0;
                    _error = null;
                  }),
                  child: const Text('Hủy'),
                ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F6FF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFDCEAFF)),
            ),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _brand, width: 2.5),
                        color: Colors.white,
                      ),
                      child: _Avatar(
                        value: _imageData.isNotEmpty
                            ? _imageData
                            : _imageUrl.text,
                        name: _name.text,
                        size: 98,
                      ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: 0,
                      child: Material(
                        color: _brand,
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: IconButton(
                          tooltip: 'Thay ảnh đại diện',
                          onPressed: () => _pickImage(),
                          icon: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                const Text(
                  'Ảnh đại diện',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Thêm ảnh để mọi người nhận ra bạn',
                  style: TextStyle(color: _muted, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickImage(),
                      icon: const Icon(Icons.photo_library_outlined, size: 17),
                      label: Text(
                        kIsWeb
                            ? 'Chọn ảnh từ máy tính'
                            : 'Chọn ảnh từ thiết bị',
                      ),
                    ),
                    if (!kIsWeb)
                      OutlinedButton.icon(
                        onPressed: () => _pickImage(source: ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined, size: 17),
                        label: const Text('Chụp ảnh'),
                      ),
                    if (_imageData.isNotEmpty || _imageUrl.text.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _imageData = '';
                          _imageUrl.clear();
                        }),
                        icon: const Icon(Icons.delete_outline, size: 17),
                        label: const Text('Bỏ ảnh'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFD94C58),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 17),
          _Field(
            label: 'Họ và tên',
            controller: _name,
            hint: 'Nguyễn Văn A',
            large: true,
            validator: _required,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 13),
          _Field(
            label: 'Email',
            controller: _email,
            hint: 'ban@example.com',
            keyboardType: TextInputType.emailAddress,
            large: true,
            validator: _emailValidator,
          ),
          const SizedBox(height: 13),
          if (_editingId == null || _editingProfile) ...[
            if (_editingProfile) ...[
              _Field(
                label: 'Mật khẩu hiện tại (để xác minh)',
                controller: _currentPassword,
                hint: 'Nhập mật khẩu hiện tại',
                large: true,
                obscure: true,
                showPasswordToggle: true,
                validator: (_) =>
                    _password.text.isNotEmpty && _currentPassword.text.isEmpty
                    ? 'Cần nhập mật khẩu hiện tại để đổi mật khẩu.'
                    : null,
              ),
              const SizedBox(height: 13),
            ],
            _Field(
              label: _editingId == null
                  ? 'Mật khẩu'
                  : 'Mật khẩu mới (không bắt buộc)',
              controller: _password,
              hint: 'Ít nhất 6 ký tự',
              large: true,
              obscure: true,
              showPasswordToggle: true,
              validator: (value) =>
                  _editingId != null && (value == null || value.isEmpty)
                  ? null
                  : _passwordValidator(value),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline_rounded, color: _brand, size: 19),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Mật khẩu chỉ được chính chủ thay đổi trong mục Tài khoản.',
                      style: TextStyle(color: _muted, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          if (_error != null) _ErrorText(_error!),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _saveUser,
              icon: Icon(
                _editingId == null ? Icons.person_add_alt : Icons.save_outlined,
                size: 18,
              ),
              label: Text(
                _saving
                    ? 'Đang lưu...'
                    : _editingId == null
                    ? 'Thêm người dùng'
                    : 'Lưu thay đổi',
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _userList() {
    final term = _search.text.trim().toLowerCase();
    final shown = _users
        .where(
          (user) =>
              '${user['hoten']} ${user['email']}'.toLowerCase().contains(
                term,
              ) &&
              (_avatarFilter == 0 ||
                  ((user['hinhanh'] ?? '').toString().trim().isNotEmpty) ==
                      (_avatarFilter == 1)),
        )
        .toList();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Kicker('DANH BẠ'),
                  SizedBox(height: 5),
                  Text(
                    'Danh sách người dùng',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Làm mới',
                onPressed: () async {
                  try {
                    await _loadUsers();
                    if (mounted) setState(() => _error = null);
                  } catch (error) {
                    if (mounted) setState(() => _error = _message(error));
                  }
                },
                icon: const Icon(Icons.refresh, color: _brand),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_error != null) _ErrorText(_error!),
          TextField(
            controller: _search,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Tìm theo tên hoặc email...',
              isDense: true,
              suffixIcon: term.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      onPressed: _search.clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            children: [
              _MemberFilterChip(
                label: 'Tất cả (${_users.length})',
                selected: _avatarFilter == 0,
                onSelected: () => setState(() => _avatarFilter = 0),
              ),
              _MemberFilterChip(
                label: 'Có ảnh',
                selected: _avatarFilter == 1,
                onSelected: () => setState(() => _avatarFilter = 1),
              ),
              _MemberFilterChip(
                label: 'Thiếu ảnh',
                selected: _avatarFilter == 2,
                onSelected: () => setState(() => _avatarFilter = 2),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Text(
                      _users.isEmpty
                          ? 'Chưa có người dùng'
                          : 'Không tìm thấy kết quả',
                      style: const TextStyle(color: _muted),
                    ),
                  )
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, index) {
                      final user = shown[index];
                      final name = user['hoten']?.toString() ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE8ECF7)),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x080D1B49),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _Avatar(
                                  value: user['hinhanh']?.toString() ?? '',
                                  name: name,
                                  size: 54,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: _ink,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        user['email']?.toString() ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: _muted,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.verified_rounded,
                                  color: Color(0xFF14A77A),
                                  size: 16,
                                ),
                                IconButton(
                                  tooltip: 'Sao chép email',
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 17,
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(
                                        text: user['email']?.toString() ?? '',
                                      ),
                                    );
                                    if (mounted) _snack('Đã sao chép email');
                                  },
                                  icon: const Icon(Icons.content_copy_rounded),
                                ),
                              ],
                            ),
                            const Divider(height: 13, color: _line),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Icon(
                                  Icons.lock_outline,
                                  size: 13,
                                  color: _muted,
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'Mật khẩu được bảo vệ',
                                  style: TextStyle(color: _muted, fontSize: 14),
                                ),

                                _SmallAction(
                                  label: 'Sửa',
                                  icon: Icons.edit_outlined,
                                  onTap: () => _editUser(
                                    user,
                                    profile:
                                        (user['id'] ?? user['_id']) ==
                                        (_me?['id'] ?? _me?['_id']),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _SmallAction(
                                  label: 'Xóa',
                                  icon: Icons.delete_outline,
                                  danger: true,
                                  onTap: () => _deleteUser(user),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _profilePage() {
    final user = _me!;
    return ListView(
      children: [
        _Card(
          radius: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Kicker('TRANG CÁ NHÂN'),
              const SizedBox(height: 22),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _brand, width: 3),
                  ),
                  child: _Avatar(
                    value: user['hinhanh']?.toString() ?? '',
                    name: user['hoten']?.toString() ?? '',
                    size: 112,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                user['hoten']?.toString() ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                user['email']?.toString() ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, color: _muted),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => _editUser(user, profile: true),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Chỉnh sửa hồ sơ'),
              ),
              const SizedBox(height: 26),
              const Divider(color: _line),
              const SizedBox(height: 13),
              const Text(
                'Thông tin cá nhân',
                style: TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 15),
              for (final entry in <String, String>{
                'Email': user['email']?.toString() ?? '',
              }.entries) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 11),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F9FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(color: _muted, fontSize: 16),
                      ),
                      const SizedBox(height: 5),
                      SelectableText(
                        entry.value.isEmpty ? 'Chưa cập nhật' : entry.value,
                        style: const TextStyle(
                          fontSize: 19,
                          color: _ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? 'Vui lòng nhập thông tin này.'
      : null;
  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Vui lòng nhập email.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
      return 'Email chưa đúng định dạng.';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu.';
    if (value.length < 6) return 'Mật khẩu cần ít nhất 6 ký tự.';
    return null;
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _line),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0B4558C5),
          blurRadius: 36,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: active ? const Color(0xFFDEECFF) : Colors.white,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: active ? _brandDeep : _muted),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: active ? _brandDeep : _muted,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 145),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x101641D8),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MemberFilterChip extends StatelessWidget {
  const _MemberFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
    showCheckmark: false,
    visualDensity: VisualDensity.compact,
    labelStyle: TextStyle(
      color: selected ? _brandDeep : _muted,
      fontSize: 15,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    ),
    side: BorderSide(color: selected ? const Color(0xFFA8CAFF) : _line),
    backgroundColor: Colors.white,
    selectedColor: const Color(0xFFE7F0FF),
  );
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFFEEEE) : const Color(0xFFE7F0FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: danger ? const Color(0xFFD94C58) : _brandDeep,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: danger ? const Color(0xFFD94C58) : _brandDeep,
            ),
          ),
        ],
      ),
    ),
  );
}

class _DotPainter extends CustomPainter {
  const _DotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const step = 10.0;
    final paint = Paint()
      ..color = const Color(0xFF223B7A).withValues(alpha: .07);
    for (var y = 4.0; y < size.height; y += step) {
      for (var x = 4.0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 0.55, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Kicker extends StatelessWidget {
  const _Kicker(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: _brand,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.3,
    ),
  );
}

class _Feature extends StatelessWidget {
  const _Feature({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        const Icon(
          Icons.check_circle_outline,
          color: Color(0xFF21896C),
          size: 18,
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(color: Color(0xFF58647B), fontSize: 17),
        ),
      ],
    ),
  );
}

class _AuthTab extends StatelessWidget {
  const _AuthTab({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: active ? _ink : _muted,
              fontSize: 17,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 2,
            width: 95,
            color: active ? _brand : Colors.transparent,
          ),
        ],
      ),
    ),
  );
}

class _Field extends StatefulWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.showPasswordToggle = false,
    this.large = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final bool showPasswordToggle;
  final bool large;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late final FocusNode _focusNode;
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _obscured = widget.obscure;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _focusAndShowKeyboard() {
    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted || !_focusNode.hasFocus) return;
      await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.label,
        style: const TextStyle(
          fontSize: 17,
          color: Color(0xFF4C5870),
          fontWeight: FontWeight.w600,
        ),
      ),
      SizedBox(height: widget.large ? 9 : 7),
      TextFormField(
        focusNode: _focusNode,
        controller: widget.controller,
        obscureText: _obscured,
        keyboardType: widget.keyboardType ?? TextInputType.text,
        validator: widget.validator,
        onChanged: widget.onChanged,
        onTap: _focusAndShowKeyboard,
        onTapOutside: (_) => _focusNode.unfocus(),
        textInputAction: widget.obscure
            ? TextInputAction.done
            : TextInputAction.next,
        autocorrect: !widget.obscure,
        enableSuggestions: !widget.obscure,
        showCursor: true,
        readOnly: false,
        enableInteractiveSelection: true,
        style: TextStyle(fontSize: widget.large ? 20 : 19, color: _ink),
        decoration: InputDecoration(
          hintText: widget.hint,
          contentPadding: widget.large
              ? const EdgeInsets.symmetric(horizontal: 18, vertical: 19)
              : null,
          suffixIcon: widget.showPasswordToggle
              ? IconButton(
                  tooltip: _obscured ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  onPressed: () => setState(() => _obscured = !_obscured),
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                )
              : null,
        ),
      ),
    ],
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(color: Color(0xFFB84545), fontSize: 16),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.value, required this.name, required this.size});
  final String value;
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final letters = initials.isEmpty
        ? '?'
        : initials
              .skip(initials.length > 1 ? initials.length - 2 : 0)
              .map((part) => part[0])
              .join()
              .toUpperCase();
    ImageProvider? provider;
    if (value.startsWith('data:') && value.contains(',')) {
      try {
        provider = MemoryImage(
          base64Decode(value.substring(value.indexOf(',') + 1)),
        );
      } catch (_) {
        provider = null;
      }
    } else if (value.startsWith('http://') || value.startsWith('https://')) {
      provider = NetworkImage(value);
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFEDF0FF),
      backgroundImage: provider,
      onBackgroundImageError: provider == null ? null : (_, _) {},
      child: provider == null
          ? Text(
              letters,
              style: const TextStyle(
                color: _brand,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}
