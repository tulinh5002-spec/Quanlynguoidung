# User Management — Flutter + MongoDB

The project contains a Flutter app, an Express/MongoDB API, and an older Expo prototype in `mobile/`. Use `flutter_app/` for the current assignment.

## Run the Android app in an emulator

1. Configure `backend/.env` with `MONGO_URI` and a `JWT_SECRET` of at least 32 characters. Start the API in a terminal from the project root:

   ```cmd
   cd backend
   npm install
   npm start
   ```

   Keep this terminal open. The health endpoint is `http://localhost:3000/api/health`.

2. Start the Android virtual device. If it is already open, skip this command:

   ```powershell
   & "F:\DevTools\Android\sdk\emulator\emulator.exe" -avd FlutterPhone
   ```

   `FlutterPhone` is configured at 320 dpi for a 540 dp-wide app viewport; its pixel resolution and 2 GB RAM allocation are unchanged. Power it off and start it once with `-no-snapshot-load` to apply the new density. Use the emulator toolbar's zoom button to enlarge its window on the desktop without increasing app memory use.

3. In a new **CMD** terminal, set Java 17 and run Flutter. The `U:` drive avoids Gradle wrapper issues with this workspace's Vietnamese path:

   ```cmd
   subst U: "F:\Phát triển ứng dụng di động đa nền tảng\user-management"
   set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.21.9-hotspot"
   set "PATH=%JAVA_HOME%\bin;%PATH%"
   cd /d U:\flutter_app
   flutter pub get
   flutter devices
   flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000
   ```

   The emulator must appear in `flutter devices`. `10.0.2.2` is the emulator's route to the computer running the API. The first Android build can take several minutes.

## Run Flutter Web on the computer

With the backend running, open another terminal:

```cmd
cd /d "F:\Phát triển ứng dụng di động đa nền tảng\user-management\flutter_app"
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

The Android app and web app use the same API. For API routes and MongoDB export instructions, see [backend/README.md](backend/README.md); for Flutter details, see [flutter_app/README.md](flutter_app/README.md).

## Màn hình rộng và ảnh từ máy tính

Máy ảo `FlutterWide` dùng màn hình điện thoại dọc 1080 × 2160 (360 dpi, chiều rộng giao diện 480 dp). Khởi động bằng:

```powershell
powershell -ExecutionPolicy Bypass -File tools/start-wide-emulator.ps1
```

Để chọn ảnh trên máy tính cho Android, chạy `powershell -ExecutionPolicy Bypass -File tools/import-emulator-images.ps1`, chọn ảnh, sau đó bấm **Chọn ảnh từ thiết bị** trong ứng dụng. Có thể truyền `-Device emulator-5556` nếu dùng cổng khác. Trên Flutter Web, nút **Chọn ảnh từ máy tính** mở trực tiếp hộp chọn tệp.

Trang **Tài khoản** hiển thị hồ sơ, gồm địa chỉ. Bấm **Cập nhật thông tin** để sửa. Ngày sinh có thể nhập theo `YYYY-MM-DD` hoặc chọn lịch. Địa chỉ được lưu ở trường `diachi` trong MongoDB; cần khởi động lại backend sau khi cập nhật mã.

Nếu Gboard chỉ hiện thanh công cụ viết tay ở cạnh màn hình, chọn lại bàn phím QWERTY trong cài đặt ngôn ngữ Gboard. Máy ảo hiện đã được chuyển sang QWERTY và bật hiển thị bàn phím ảo khi dùng bàn phím máy tính; không cần sửa kiểu nhập của các trường Flutter.
