$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path $PSScriptRoot -Parent
$appPath = Join-Path $workspaceRoot 'app'
$stagePath = Join-Path $workspaceRoot ('.build/exe-stage-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $stagePath -Force | Out-Null
$runtimeFiles = @('app.js','index.html','style.css','stats.html','stats.js','stats.css','analytics.cjs','usage-archive.cjs','cost.cjs','launch.ps1','mascot-title.png','mascot.ico','mascot.png','metrics.cjs','NODE-LICENSE.txt','package.json','pricing.json','quota-client.cjs','refresh-policy.cjs','reset-cache.cjs','server.cjs','stop.ps1','widget.ps1','启动面板.cmd','停止监控.cmd')
foreach ($name in $runtimeFiles) { Copy-Item -LiteralPath (Join-Path $appPath $name) -Destination (Join-Path $stagePath $name) -Force }
Copy-Item -LiteralPath (Get-Command node.exe).Source -Destination (Join-Path $stagePath 'node.exe') -Force
$zipPath = Join-Path $workspaceRoot '.build/payload.zip'
Compress-Archive -Path (Join-Path $stagePath '*') -DestinationPath $zipPath -Force -CompressionLevel Optimal
$compilerPath = Join-Path $env:SystemRoot 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
New-Item -ItemType Directory -Path (Join-Path $workspaceRoot 'dist') -Force | Out-Null
$outputPath = Join-Path $workspaceRoot 'dist/CodexUsageMonitor.exe'
& $compilerPath /nologo /target:winexe /platform:x64 /optimize+ "/out:$outputPath" "/win32icon:$(Join-Path $appPath 'mascot.ico')" /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll /reference:System.Windows.Forms.dll "/resource:$zipPath,Payload" (Join-Path $PSScriptRoot 'Launcher.cs')
if ($LASTEXITCODE -ne 0) { throw 'EXE compilation failed' }
Get-Item -LiteralPath $outputPath | Select-Object Name,Length
