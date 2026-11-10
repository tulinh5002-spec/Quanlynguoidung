import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator, Alert, FlatList, Image, KeyboardAvoidingView, Platform,
  Pressable, SafeAreaView, ScrollView, StatusBar, StyleSheet, Text,
  TextInput, View,
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as ImagePicker from 'expo-image-picker';

const TOKEN_KEY = 'user_management_token';
const API_URL = (process.env.EXPO_PUBLIC_API_URL || (Platform.OS === 'android' ? 'http://10.0.2.2:3000' : 'http://localhost:3000')).replace(/\/$/, '');
const colors = { ink: '#18233b', muted: '#78849a', blue: '#4d63dc', pale: '#f4f6fb', line: '#e6eaf1', green: '#21896c', red: '#c75252', white: '#ffffff' };

async function api(path, { token, ...options } = {}) {
  const headers = { ...(options.body ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}), ...options.headers };
  let response;
  try {
    response = await fetch(`${API_URL}${path}`, { ...options, headers });
  } catch (_) {
    throw new Error(`Không kết nối được máy chủ tại ${API_URL}. Kiểm tra backend và địa chỉ API.`);
  }
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.message || `Lỗi máy chủ (${response.status})`);
  return data;
}

function Button({ title, onPress, secondary, danger, disabled, compact, style }) {
  return <Pressable accessibilityRole="button" disabled={disabled} onPress={onPress} style={({ pressed }) => [styles.button, secondary && styles.buttonSecondary, danger && styles.buttonDanger, compact && styles.buttonCompact, disabled && styles.buttonDisabled, pressed && !disabled && styles.pressed, style]}>
    {disabled ? <ActivityIndicator color={secondary ? colors.blue : colors.white} size="small" /> : <Text style={[styles.buttonText, secondary && styles.buttonSecondaryText, danger && styles.buttonDangerText, compact && styles.buttonCompactText]}>{title}</Text>}
  </Pressable>;
}

function Avatar({ uri, name, size = 46 }) {
  const initials = (name || '?').trim().split(/\s+/).slice(-2).map((part) => part[0] || '').join('').toUpperCase();
  return <View style={[styles.avatar, { width: size, height: size, borderRadius: size / 2 }]}>{uri ? <Image source={{ uri }} style={{ width: size, height: size, borderRadius: size / 2 }} /> : <Text style={styles.avatarLetters}>{initials}</Text>}</View>;
}

export default function App() {
  const [token, setToken] = useState(null);
  const [me, setMe] = useState(null);
  const [booting, setBooting] = useState(true);
  const [authMode, setAuthMode] = useState('login');
  const [auth, setAuth] = useState({ email: '', matkhau: '', hoten: '' });
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [search, setSearch] = useState('');
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState({ email: '', matkhau: '', hoten: '', hinhanh: '' });
  const [notice, setNotice] = useState('');

  const updateForm = (key, value) => setForm((current) => ({ ...current, [key]: value }));
  const updateAuth = (key, value) => setAuth((current) => ({ ...current, [key]: value }));

  const loadUsers = useCallback(async (activeToken = token) => {
    if (!activeToken) return;
    setLoading(true);
    try {
      const result = await api('/api/users', { token: activeToken });
      setUsers(result);
      setNotice('');
    } catch (error) {
      if (/Token|đăng nhập/i.test(error.message)) await signOut(false);
      else setNotice(error.message);
    } finally { setLoading(false); }
  }, [token]);

  const signOut = useCallback(async (notify = true) => {
    await AsyncStorage.removeItem(TOKEN_KEY);
    setToken(null); setMe(null); setUsers([]); setEditingId(null);
    setForm({ email: '', matkhau: '', hoten: '', hinhanh: '' });
    if (notify) setNotice('Bạn đã đăng xuất.');
  }, []);

  useEffect(() => {
    let alive = true;
    (async () => {
      const storedToken = await AsyncStorage.getItem(TOKEN_KEY);
      if (!storedToken) { if (alive) setBooting(false); return; }
      try {
        const result = await api('/api/users/me', { token: storedToken });
        if (!alive) return;
        setToken(storedToken); setMe(result.user);
        const list = await api('/api/users', { token: storedToken });
        if (alive) setUsers(list);
      } catch (_) {
        await AsyncStorage.removeItem(TOKEN_KEY);
      } finally { if (alive) setBooting(false); }
    })();
    return () => { alive = false; };
  }, []);

  const visibleUsers = useMemo(() => {
    const term = search.trim().toLocaleLowerCase('vi');
    return users.filter((user) => `${user.hoten} ${user.email}`.toLocaleLowerCase('vi').includes(term));
  }, [users, search]);

  async function submitAuth() {
    const email = auth.email.trim();
    if (!email || !auth.matkhau || (authMode === 'register' && !auth.hoten.trim())) {
      setNotice('Vui lòng nhập đầy đủ thông tin.'); return;
    }
    if (auth.matkhau.length < 6) { setNotice('Mật khẩu cần ít nhất 6 ký tự.'); return; }
    setSaving(true); setNotice('');
    try {
      if (authMode === 'register') {
        await api('/api/users', { method: 'POST', body: JSON.stringify({ email, matkhau: auth.matkhau, hoten: auth.hoten.trim() }) });
      }
      const result = await api('/api/users/login', { method: 'POST', body: JSON.stringify({ email, matkhau: auth.matkhau }) });
      await AsyncStorage.setItem(TOKEN_KEY, result.token);
      setToken(result.token); setMe(result.user); setAuth({ email: '', matkhau: '', hoten: '' });
      await loadUsers(result.token);
    } catch (error) { setNotice(error.message); }
    finally { setSaving(false); }
  }

  function clearForm() {
    setEditingId(null); setForm({ email: '', matkhau: '', hoten: '', hinhanh: '' }); setNotice('');
  }

  function editUser(user) {
    setEditingId(user.id || user._id);
    setForm({ email: user.email || '', matkhau: '', hoten: user.hoten || '', hinhanh: user.hinhanh || '' });
    setNotice('');
  }

  async function chooseImage(useCamera) {
    try {
      if (useCamera) {
        const permission = await ImagePicker.requestCameraPermissionsAsync();
        if (!permission.granted) { Alert.alert('Cần quyền camera', 'Hãy cho phép ứng dụng dùng camera để chụp ảnh.'); return; }
      } else {
        const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
        if (!permission.granted) { Alert.alert('Cần quyền thư viện ảnh', 'Hãy cho phép ứng dụng truy cập ảnh trên thiết bị.'); return; }
      }
      const result = useCamera
        ? await ImagePicker.launchCameraAsync({ mediaTypes: ['images'], allowsEditing: true, aspect: [1, 1], quality: 0.65, base64: true })
        : await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], allowsEditing: true, aspect: [1, 1], quality: 0.65, base64: true });
      if (!result.canceled && result.assets?.[0]) {
        const asset = result.assets[0];
        if (!asset.base64) { setNotice('Không đọc được dữ liệu ảnh. Hãy thử ảnh khác.'); return; }
        const mime = asset.mimeType || 'image/jpeg';
        updateForm('hinhanh', `data:${mime};base64,${asset.base64}`);
        setNotice('');
      }
    } catch (error) { setNotice(`Không mở được ảnh: ${error.message}`); }
  }

  function askForImage() {
    Alert.alert('Ảnh đại diện', 'Chọn cách thêm ảnh', [
      { text: 'Chụp ảnh', onPress: () => chooseImage(true) },
      { text: 'Chọn từ thư viện', onPress: () => chooseImage(false) },
      { text: 'Hủy', style: 'cancel' },
    ]);
  }

  async function saveUser() {
    if (!form.hoten.trim() || !form.email.trim() || (!editingId && !form.matkhau)) { setNotice('Nhập họ tên, email và mật khẩu.'); return; }
    const payload = { hoten: form.hoten.trim(), email: form.email.trim(), hinhanh: form.hinhanh };
    if (form.matkhau) payload.matkhau = form.matkhau;
    setSaving(true); setNotice('');
    try {
      const isEditing = Boolean(editingId);
      await api(isEditing ? `/api/users/${encodeURIComponent(editingId)}` : '/api/users', {
        method: isEditing ? 'PUT' : 'POST', token, body: JSON.stringify(payload),
      });
      clearForm();
      await loadUsers();
      Alert.alert('Hoàn tất', isEditing ? 'Đã cập nhật người dùng.' : 'Đã thêm người dùng.');
    } catch (error) { setNotice(error.message); }
    finally { setSaving(false); }
  }

  function deleteUser(user) {
    Alert.alert('Xóa người dùng', `Xóa tài khoản ${user.email}?`, [
      { text: 'Hủy', style: 'cancel' },
      { text: 'Xóa', style: 'destructive', onPress: async () => {
        try {
          await api(`/api/users/${encodeURIComponent(user.id || user._id)}`, { method: 'DELETE', token });
          if (editingId === (user.id || user._id)) clearForm();
          await loadUsers();
        } catch (error) { setNotice(error.message); }
      } },
    ]);
  }

  if (booting) return <SafeAreaView style={styles.boot}><StatusBar barStyle="dark-content" /><ActivityIndicator size="large" color={colors.blue} /><Text style={styles.bootText}>Đang kết nối...</Text></SafeAreaView>;

  if (!token) return <SafeAreaView style={styles.safe}>
    <StatusBar barStyle="dark-content" backgroundColor={colors.pale} />
    <KeyboardAvoidingView style={styles.flex} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView contentContainerStyle={styles.authScroll} keyboardShouldPersistTaps="handled">
        <View style={styles.authBrand}><View style={styles.logo}><Text style={styles.logoText}>U</Text></View><Text style={styles.brandName}>User<Text style={styles.brandLight}>Desk</Text></Text></View>
        <Text style={styles.kicker}>QUẢN LÝ NGƯỜI DÙNG</Text>
        <Text style={styles.authTitle}>{authMode === 'login' ? 'Chào mừng trở lại' : 'Tạo tài khoản mới'}</Text>
        <Text style={styles.subtitle}>{authMode === 'login' ? 'Đăng nhập để quản lý danh sách người dùng.' : 'Tạo tài khoản để bắt đầu sử dụng ứng dụng.'}</Text>
        <View style={styles.card}>
          <View style={styles.authTabs}>
            <Pressable onPress={() => { setAuthMode('login'); setNotice(''); }} style={[styles.authTab, authMode === 'login' && styles.authTabActive]}><Text style={[styles.authTabText, authMode === 'login' && styles.authTabTextActive]}>Đăng nhập</Text></Pressable>
            <Pressable onPress={() => { setAuthMode('register'); setNotice(''); }} style={[styles.authTab, authMode === 'register' && styles.authTabActive]}><Text style={[styles.authTabText, authMode === 'register' && styles.authTabTextActive]}>Tạo tài khoản</Text></Pressable>
          </View>
          {authMode === 'register' && <Field label="Họ và tên" value={auth.hoten} onChangeText={(value) => updateAuth('hoten', value)} placeholder="Nguyễn Văn A" />}
          <Field label="Email" value={auth.email} onChangeText={(value) => updateAuth('email', value)} placeholder="ban@example.com" keyboardType="email-address" autoCapitalize="none" />
          <Field label="Mật khẩu" value={auth.matkhau} onChangeText={(value) => updateAuth('matkhau', value)} placeholder="Ít nhất 6 ký tự" secureTextEntry />
          <Button title={authMode === 'login' ? 'Đăng nhập' : 'Tạo tài khoản'} onPress={submitAuth} disabled={saving} style={styles.fullButton} />
          {!!notice && <Text accessibilityRole="alert" style={styles.error}>{notice}</Text>}
        </View>
        <Text style={styles.authFoot}>Dữ liệu hồ sơ được lưu an toàn trong MongoDB.</Text>
      </ScrollView>
    </KeyboardAvoidingView>
  </SafeAreaView>;

  return <SafeAreaView style={styles.safe}>
    <StatusBar barStyle="dark-content" backgroundColor={colors.pale} />
    <View style={styles.header}>
      <View style={styles.headerBrand}><View style={styles.logoSmall}><Text style={styles.logoText}>U</Text></View><Text style={styles.brandNameSmall}>UserDesk</Text></View>
      <Pressable onPress={() => signOut()} style={styles.logout}><Text style={styles.logoutText}>Đăng xuất</Text></Pressable>
    </View>
    <FlatList
      data={visibleUsers}
      keyExtractor={(item) => String(item.id || item._id)}
      keyboardShouldPersistTaps="handled"
      contentContainerStyle={styles.listContent}
      ListHeaderComponent={<>
        <View style={styles.headingRow}><View><Text style={styles.kicker}>KHÔNG GIAN QUẢN TRỊ</Text><Text style={styles.pageTitle}>Người dùng</Text><Text style={styles.subtitle}>Xin chào, {me?.hoten || me?.email}</Text></View><View style={styles.count}><Text style={styles.countNumber}>{users.length}</Text><Text style={styles.countLabel}>tài khoản</Text></View></View>
        <View style={styles.card}>
          <View style={styles.formHeading}><View><Text style={styles.kicker}>{editingId ? 'CHỈNH SỬA HỒ SƠ' : 'TÀI KHOẢN MỚI'}</Text><Text style={styles.cardTitle}>{editingId ? 'Cập nhật người dùng' : 'Thêm người dùng'}</Text></View>{editingId && <Pressable onPress={clearForm}><Text style={styles.link}>Hủy sửa</Text></Pressable>}</View>
          <View style={styles.imagePickerRow}><Avatar uri={form.hinhanh} name={form.hoten} size={64} /><View style={styles.imagePickerButtons}><Button title="Chụp ảnh" secondary compact onPress={() => chooseImage(true)} /><Button title="Thư viện ảnh" secondary compact onPress={() => chooseImage(false)} /></View></View>
          <Field label="Họ và tên" value={form.hoten} onChangeText={(value) => updateForm('hoten', value)} placeholder="Nguyễn Văn A" />
          <Field label="Email" value={form.email} onChangeText={(value) => updateForm('email', value)} placeholder="ban@example.com" keyboardType="email-address" autoCapitalize="none" />
          <Field label={editingId ? 'Mật khẩu (để trống nếu không đổi)' : 'Mật khẩu'} value={form.matkhau} onChangeText={(value) => updateForm('matkhau', value)} placeholder="Ít nhất 6 ký tự" secureTextEntry />
          <Field label="Hoặc URL ảnh" value={form.hinhanh.startsWith('data:') ? '' : form.hinhanh} onChangeText={(value) => updateForm('hinhanh', value)} placeholder="https://example.com/avatar.jpg" autoCapitalize="none" />
          <Button title={editingId ? 'Lưu thay đổi' : 'Thêm người dùng'} onPress={saveUser} disabled={saving} style={styles.fullButton} />
          {!!notice && <Text accessibilityRole="alert" style={styles.error}>{notice}</Text>}
        </View>
        <View style={styles.listHeading}><View><Text style={styles.kicker}>DANH BẠ</Text><Text style={styles.cardTitle}>Danh sách người dùng</Text></View><Pressable onPress={() => loadUsers()} accessibilityLabel="Làm mới"><Text style={styles.refresh}>↻</Text></Pressable></View>
        <Field label="" value={search} onChangeText={setSearch} placeholder="Tìm theo tên hoặc email..." />
        {loading && <ActivityIndicator color={colors.blue} style={styles.loader} />}
      </>}
      renderItem={({ item }) => <View style={styles.userCard}>
        <Avatar uri={item.hinhanh} name={item.hoten} />
        <View style={styles.userDetails}><Text style={styles.userName} numberOfLines={1}>{item.hoten}</Text><Text style={styles.userEmail} numberOfLines={1}>{item.email}</Text></View>
        <Pressable onPress={() => editUser(item)} style={styles.actionButton} accessibilityLabel={`Sửa ${item.hoten}`}><Text style={styles.editIcon}>✎</Text></Pressable>
        <Pressable onPress={() => deleteUser(item)} style={[styles.actionButton, styles.deleteAction]} accessibilityLabel={`Xóa ${item.hoten}`}><Text style={styles.deleteIcon}>×</Text></Pressable>
      </View>}
      ListEmptyComponent={!loading ? <View style={styles.empty}><Text style={styles.emptyIcon}>◎</Text><Text style={styles.emptyTitle}>{search ? 'Không tìm thấy kết quả' : 'Chưa có người dùng'}</Text><Text style={styles.emptyBody}>{search ? 'Hãy thử từ khóa khác.' : 'Thêm tài khoản đầu tiên bằng biểu mẫu phía trên.'}</Text></View> : null}
      ListFooterComponent={<Text style={styles.footer}>Hồ sơ người dùng được lưu trong MongoDB.</Text>}
    />
  </SafeAreaView>;
}

function Field({ label, value, onChangeText, ...props }) {
  return <View style={styles.fieldWrap}>{!!label && <Text style={styles.fieldLabel}>{label}</Text>}<TextInput value={value} onChangeText={onChangeText} placeholderTextColor="#aab2c0" style={styles.input} {...props} /></View>;
}

const styles = StyleSheet.create({
  flex: { flex: 1 }, safe: { flex: 1, backgroundColor: colors.pale }, boot: { flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.pale }, bootText: { color: colors.muted, marginTop: 12, fontSize: 13 },
  authScroll: { flexGrow: 1, justifyContent: 'center', paddingHorizontal: 22, paddingVertical: 30 }, authBrand: { flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 46 }, logo: { width: 38, height: 38, borderRadius: 12, backgroundColor: colors.blue, alignItems: 'center', justifyContent: 'center' }, logoSmall: { width: 30, height: 30, borderRadius: 9, backgroundColor: colors.blue, alignItems: 'center', justifyContent: 'center' }, logoText: { color: colors.white, fontSize: 18, fontWeight: '800' }, brandName: { color: colors.ink, fontSize: 21, fontWeight: '800' }, brandLight: { color: '#8791a4', fontWeight: '500' }, kicker: { color: colors.blue, fontSize: 10, fontWeight: '800', letterSpacing: 1.3 }, authTitle: { color: colors.ink, fontSize: 31, fontWeight: '800', letterSpacing: -1, marginTop: 10 }, subtitle: { color: colors.muted, fontSize: 13, lineHeight: 20, marginTop: 7, marginBottom: 20 }, card: { backgroundColor: colors.white, borderRadius: 16, borderWidth: 1, borderColor: colors.line, padding: 19, marginBottom: 18, shadowColor: '#24345c', shadowOpacity: 0.04, shadowRadius: 16, shadowOffset: { width: 0, height: 8 }, elevation: 2 }, authTabs: { flexDirection: 'row', borderBottomWidth: 1, borderBottomColor: colors.line, marginBottom: 20, gap: 22 }, authTab: { paddingBottom: 11, borderBottomWidth: 2, borderBottomColor: 'transparent' }, authTabActive: { borderBottomColor: colors.blue }, authTabText: { color: '#929bad', fontSize: 12 }, authTabTextActive: { color: colors.ink, fontWeight: '700' }, fieldWrap: { marginBottom: 14 }, fieldLabel: { color: '#4c5870', fontSize: 11, fontWeight: '700', marginBottom: 7 }, input: { minHeight: 44, borderWidth: 1, borderColor: colors.line, borderRadius: 8, paddingHorizontal: 11, paddingVertical: 10, color: colors.ink, backgroundColor: colors.white, fontSize: 13 }, button: { minHeight: 42, paddingHorizontal: 15, borderRadius: 8, backgroundColor: colors.blue, alignItems: 'center', justifyContent: 'center' }, buttonSecondary: { minHeight: 35, backgroundColor: '#f4f6ff', borderWidth: 1, borderColor: '#e1e5fb' }, buttonDanger: { backgroundColor: '#fff3f3', borderColor: '#f5dddd', borderWidth: 1 }, buttonCompact: { minHeight: 34, paddingHorizontal: 10 }, buttonDisabled: { opacity: 0.65 }, buttonText: { color: colors.white, fontSize: 12, fontWeight: '700' }, buttonSecondaryText: { color: colors.blue }, buttonDangerText: { color: colors.red }, buttonCompactText: { fontSize: 11 }, pressed: { opacity: 0.8 }, fullButton: { width: '100%', marginTop: 3 }, error: { color: '#b84545', fontSize: 12, marginTop: 10, lineHeight: 18 }, authFoot: { color: '#a0a8b6', fontSize: 11, textAlign: 'center', marginTop: 16 },
  header: { height: 58, paddingHorizontal: 18, borderBottomWidth: 1, borderBottomColor: colors.line, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }, headerBrand: { flexDirection: 'row', alignItems: 'center', gap: 9 }, brandNameSmall: { color: colors.ink, fontSize: 16, fontWeight: '800' }, logout: { paddingVertical: 8, paddingHorizontal: 11, borderRadius: 7, borderWidth: 1, borderColor: colors.line, backgroundColor: colors.white }, logoutText: { fontSize: 11, color: '#626f87', fontWeight: '600' }, listContent: { padding: 17, paddingBottom: 32 }, headingRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 18 }, pageTitle: { color: colors.ink, fontSize: 29, fontWeight: '800', marginTop: 6 }, count: { minWidth: 76, paddingHorizontal: 12, paddingVertical: 10, borderWidth: 1, borderColor: colors.line, borderRadius: 11, backgroundColor: colors.white }, countNumber: { color: colors.blue, fontSize: 23, fontWeight: '800' }, countLabel: { color: colors.muted, fontSize: 10, marginTop: 2 }, formHeading: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 17 }, cardTitle: { color: colors.ink, fontSize: 17, fontWeight: '800', marginTop: 5 }, link: { color: colors.blue, fontSize: 11, fontWeight: '700' }, imagePickerRow: { flexDirection: 'row', alignItems: 'center', gap: 13, marginBottom: 18 }, imagePickerButtons: { flexDirection: 'row', flexWrap: 'wrap', gap: 7 }, avatar: { backgroundColor: '#edf0ff', alignItems: 'center', justifyContent: 'center', overflow: 'hidden' }, avatarLetters: { color: '#596cce', fontSize: 13, fontWeight: '800' }, listHeading: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: 10, marginBottom: 14 }, refresh: { color: colors.blue, fontSize: 25, paddingHorizontal: 6 }, loader: { marginVertical: 10 }, userCard: { minHeight: 70, flexDirection: 'row', alignItems: 'center', gap: 10, paddingHorizontal: 10, paddingVertical: 10, backgroundColor: colors.white, borderRadius: 11, borderWidth: 1, borderColor: colors.line, marginBottom: 8 }, userDetails: { flex: 1, minWidth: 0 }, userName: { color: '#29354d', fontSize: 13, fontWeight: '700' }, userEmail: { color: '#929bad', fontSize: 10, marginTop: 4 }, actionButton: { width: 32, height: 32, borderWidth: 1, borderColor: colors.line, borderRadius: 8, alignItems: 'center', justifyContent: 'center' }, editIcon: { color: colors.blue, fontSize: 17 }, deleteAction: { backgroundColor: '#fffafa' }, deleteIcon: { color: colors.red, fontSize: 21, lineHeight: 24 }, empty: { paddingVertical: 28, alignItems: 'center' }, emptyIcon: { color: '#b9c1d5', fontSize: 33 }, emptyTitle: { color: '#536078', fontSize: 14, fontWeight: '700', marginTop: 7 }, emptyBody: { color: colors.muted, fontSize: 11, marginTop: 5, textAlign: 'center' }, footer: { color: '#a0a8b6', fontSize: 10, textAlign: 'center', marginTop: 19 },
});
