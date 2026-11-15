param([switch]$ServerOnly)
$ErrorActionPreference = 'Stop'
$monitorUrl = 'http://127.0.0.1:47831'
$expectedVersion = '1.8.1'
function Start-Monitor {
 $status = $null
 try { $status = Invoke-RestMethod "$monitorUrl/api/status" -TimeoutSec 2 } catch {}
 if ($status -and $status.service -eq 'CodexUsageMonitor' -and $status.version -eq $expectedVersion) {
  try { $null = Invoke-WebRequest "$monitorUrl/stats" -UseBasicParsing -TimeoutSec 2; return } catch { throw 'The local statistics page is missing. Please restart the latest EXE.' }
 }
 if ($status) {
  if ($null -eq $status.fileCount -or $null -eq $status.buckets) { throw 'Port 47831 is occupied by another application.' }
  $owner = Get-NetTCPConnection -LocalPort 47831 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty OwningProcess
  if (-not $owner) { throw 'An older backend is running. Please use Stop Monitor in its installation folder, then restart.' }
  $process = Get-CimInstance Win32_Process -Filter "ProcessId=$owner"
  if ($process.Name -ne 'node.exe' -or $process.CommandLine -notmatch '(?i)(CodexUsageMonitor|codex-usage-monitor)[\\/].*server\.cjs"?\s*$') { throw 'Port 47831 is not owned by a recognized monitor backend.' }
  & "$env:SystemRoot/System32/taskkill.exe" /PID $owner /F | Out-Null
  Start-Sleep -Milliseconds 400
 }
 $monitorCodex = (Get-Command codex.exe -ErrorAction SilentlyContinue).Source
 if (-not $monitorCodex) {
  $bin = Join-Path $env:LOCALAPPDATA 'OpenAI/Codex/bin'
  if (Test-Path -LiteralPath $bin) { $monitorCodex = (Get-ChildItem -LiteralPath $bin -Filter codex.exe -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName }
 }
 if ($monitorCodex) { $env:CODEX_USAGE_CLI = $monitorCodex }
 $monitorNode = Join-Path $PSScriptRoot 'node.exe'
 if (-not (Test-Path -LiteralPath $monitorNode)) { $monitorNode = (Get-Command node.exe -ErrorAction SilentlyContinue).Source }
 if (-not $monitorNode) { $monitorNode = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe' }
 if (-not (Test-Path -LiteralPath $monitorNode)) { throw 'Node.js is missing. Please download the complete latest EXE.' }
 $errorLog = Join-Path $PSScriptRoot 'startup-error.log'
 $outLog = Join-Path $PSScriptRoot 'startup-output.log'
 $backend = Start-Process -FilePath $monitorNode -ArgumentList @(('"' + (Join-Path $PSScriptRoot 'server.cjs') + '"')) -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -RedirectStandardError $errorLog -RedirectStandardOutput $outLog -PassThru
 for ($attempt = 0; $attempt -lt 60; $attempt++) {
  Start-Sleep -Milliseconds 250
  $backend.Refresh()
  if ($backend.HasExited) { throw "The backend exited. See $errorLog" }
  try { $ready = Invoke-RestMethod "$monitorUrl/api/status" -TimeoutSec 1; if ($ready.version -eq $expectedVersion) { $null = Invoke-WebRequest "$monitorUrl/stats" -UseBasicParsing -TimeoutSec 2; return } } catch {}
 }
 throw "The backend did not become ready. See $errorLog"
}
try {
 Start-Monitor
 if (-not $ServerOnly) { Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', ('"' + (Join-Path $PSScriptRoot 'widget.ps1') + '"')) -WorkingDirectory $PSScriptRoot -WindowStyle Hidden }
} catch {
 if ($ServerOnly) { throw }
 Add-Type -AssemblyName PresentationFramework
 [Windows.MessageBox]::Show($_.Exception.Message,'Codex monitor startup error') | Out-Null
 exit 1
}
