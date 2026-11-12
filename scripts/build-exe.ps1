$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path $PSScriptRoot -Parent
$appPath = Join-Path $workspaceRoot 'app'
$stagePath = Join-Path $workspaceRoot '.build/exe-stage'
New-Item -ItemType Directory -Path $stagePath -Force | Out-Null
Get-ChildItem -LiteralPath $appPath -File | Where-Object { $_.Name -notin @('widget-settings.json','reset-credits-cache.json') -and $_.Name -notlike '*.test.cjs' -and $_.Name -ne 'test.cjs' } | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $stagePath $_.Name) -Force }
Copy-Item -LiteralPath (Get-Command node.exe).Source -Destination (Join-Path $stagePath 'node.exe') -Force
$zipPath = Join-Path $workspaceRoot '.build/payload.zip'
Compress-Archive -Path (Join-Path $stagePath '*') -DestinationPath $zipPath -Force -CompressionLevel Optimal
$compilerPath = Join-Path $env:SystemRoot 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
New-Item -ItemType Directory -Path (Join-Path $workspaceRoot 'dist') -Force | Out-Null
$outputPath = Join-Path $workspaceRoot 'dist/CodexUsageMonitor.exe'
& $compilerPath /nologo /target:winexe /platform:x64 /optimize+ "/out:$outputPath" "/win32icon:$(Join-Path $appPath 'mascot.ico')" /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll /reference:System.Windows.Forms.dll "/resource:$zipPath,Payload" (Join-Path $PSScriptRoot 'Launcher.cs')
if ($LASTEXITCODE -ne 0) { throw 'EXE compilation failed' }
Get-Item -LiteralPath $outputPath | Select-Object Name,Length
