# Flutter user management app

This Flutter app calls the Express API in `../backend`. It can run as a native Android app or as Flutter Web.

## Run on an Android emulator

Start MongoDB and the backend first (`cd backend && npm start` from the project root). Start the `FlutterPhone` emulator, then use a CMD terminal:

```cmd
subst U: "F:\Phát triển ứng dụng di động đa nền tảng\user-management"
set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.21.9-hotspot"
set "PATH=%JAVA_HOME%\bin;%PATH%"
cd /d U:\flutter_app
flutter pub get
flutter devices
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

If the emulator has a different ID in `flutter devices`, replace `emulator-5554` with that ID. `10.0.2.2` lets the Android emulator reach the backend on the host computer. The debug Android manifest permits local HTTP; release builds should use an HTTPS API URL.

## Run in desktop Chrome

```cmd
cd /d "F:\Phát triển ứng dụng di động đa nền tảng\user-management\flutter_app"
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

For web release builds, pass the deployed backend URL:

```cmd
flutter build web --no-tree-shake-icons --dart-define=API_BASE_URL=https://your-api.example.com
```

The build output is in `build/web`. The `--no-tree-shake-icons` flag avoids icon tree-shaking problems in this Vietnamese Windows workspace path.
