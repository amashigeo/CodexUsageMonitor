$monitorScript = Join-Path $PSScriptRoot 'server.cjs'
$widgetScript = Join-Path $PSScriptRoot 'widget.ps1'
Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object {
    $_.CommandLine -and $_.CommandLine.Replace('/', '\').Contains([IO.Path]::GetFullPath($monitorScript))
} | ForEach-Object { & "$env:SystemRoot/System32/taskkill.exe" /PID $_.ProcessId /F | Out-Null }
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {
    $_.CommandLine -and $_.CommandLine.Replace('/', '\').Contains([IO.Path]::GetFullPath($widgetScript))
} | ForEach-Object { & "$env:SystemRoot/System32/taskkill.exe" /PID $_.ProcessId /F | Out-Null }
