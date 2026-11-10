$workspace = Split-Path $PSScriptRoot -Parent
if (!(Test-Path 'U:\flutter_app')) { subst U: $workspace }
$env:ANDROID_AVD_HOME = 'U:\.emulator'
$configPath = 'U:\.emulator\FlutterWide\config.ini'
$config = [IO.File]::ReadAllText($configPath)
$config = [regex]::Replace($config, '(?m)^hw.lcd.width\s*=.*$', 'hw.lcd.width = 1080')
$config = [regex]::Replace($config, '(?m)^hw.lcd.height\s*=.*$', 'hw.lcd.height = 2160')
$config = [regex]::Replace($config, '(?m)^hw.lcd.density\s*=.*$', 'hw.lcd.density = 360')
[IO.File]::WriteAllText($configPath, $config)
Start-Process -FilePath 'F:\DevTools\Android\sdk\emulator\emulator.exe' -ArgumentList '-avd FlutterWide -no-snapshot-load -gpu swiftshader_indirect -no-snapshot-save -no-skin -scale 0.4' -WindowStyle Normal
