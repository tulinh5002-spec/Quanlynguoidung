param([string]$Device = 'emulator-5554')
Add-Type -AssemblyName System.Windows.Forms
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Title = 'Chọn ảnh đưa vào máy ảo Android'
$dialog.Filter = 'Images|*.jpg;*.jpeg;*.png;*.webp'
$dialog.Multiselect = $true
if ($dialog.ShowDialog() -ne 'OK') { exit }
$adb = 'F:\DevTools\Android\sdk\platform-tools\adb.exe'
foreach ($file in $dialog.FileNames) {
  $name = [IO.Path]::GetFileName($file)
  $target = "/sdcard/Pictures/$name"
  & $adb -s $Device push $file $target
  if ($LASTEXITCODE -ne 0) { throw 'Không thể đưa ảnh vào máy ảo.' }
  & $adb -s $Device shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file://$target"
}
Write-Host 'Đã thêm ảnh. Trong ứng dụng, chọn Chọn ảnh từ thiết bị.'
