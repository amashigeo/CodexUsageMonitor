$ErrorActionPreference = 'Stop'
$monitorUrl = 'http://127.0.0.1:47831'
$monitorScript = Join-Path $PSScriptRoot 'server.cjs'
try { $null = Invoke-RestMethod "$monitorUrl/api/status" -TimeoutSec 2; $monitorRunning = $true } catch { $monitorRunning = $false }
if (-not $monitorRunning) {
    $monitorCodex = (Get-Command codex.exe -ErrorAction SilentlyContinue).Source
    if (-not $monitorCodex) {
        $monitorCodexBin = Join-Path $env:LOCALAPPDATA 'OpenAI/Codex/bin'
        if (Test-Path -LiteralPath $monitorCodexBin) {
            $monitorCodex = (Get-ChildItem -LiteralPath $monitorCodexBin -Filter codex.exe -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
        }
    }
    if ($monitorCodex) { $env:CODEX_USAGE_CLI = $monitorCodex }
    $monitorNode = Join-Path $PSScriptRoot 'node.exe'
    if (-not (Test-Path -LiteralPath $monitorNode)) { $monitorNode = (Get-Command node.exe -ErrorAction SilentlyContinue).Source }
    if (-not $monitorNode) {
        $monitorCandidate = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe'
        if (Test-Path -LiteralPath $monitorCandidate) { $monitorNode = $monitorCandidate }
    }
    if (-not $monitorNode) { throw 'Node.js 20+ is required. Install Node.js, then retry.' }
    Start-Process -FilePath $monitorNode -ArgumentList @(('"' + $monitorScript + '"')) -WorkingDirectory $PSScriptRoot -WindowStyle Hidden
    for ($monitorTry = 0; $monitorTry -lt 30; $monitorTry++) {
        Start-Sleep -Milliseconds 300
        try { $null = Invoke-RestMethod "$monitorUrl/api/status" -TimeoutSec 1; $monitorRunning = $true; break } catch {}
    }
    if (-not $monitorRunning) { throw 'Could not start monitor. Run node server.cjs to view the error.' }
}
$monitorWidget = Join-Path $PSScriptRoot 'widget.ps1'
Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $monitorWidget + '"')) -WorkingDirectory $PSScriptRoot -WindowStyle Hidden
