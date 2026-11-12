param([string]$PreviewPath, [switch]$SelfTest)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing
$widgetMutexName = if ($SelfTest) { 'Local\CodexUsageStickyTest' } else { 'Local\CodexUsageStickyV2' }
$widgetMutex = New-Object System.Threading.Mutex($false, $widgetMutexName)
if (-not $widgetMutex.WaitOne(0)) { $widgetMutex.Dispose(); exit }
$settingsPath = Join-Path $PSScriptRoot 'widget-settings.json'
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Codex 便签" Width="352" Height="570" MinWidth="280" MinHeight="340" WindowStyle="None" ResizeMode="CanResizeWithGrip" AllowsTransparency="False" Background="#F5F5E9" Topmost="True" FontFamily="Microsoft YaHei UI" FontSize="12" Foreground="#39473D" ShowInTaskbar="False">
 <WindowChrome.WindowChrome><WindowChrome CaptionHeight="0" ResizeBorderThickness="6" GlassFrameThickness="0" CornerRadius="9" UseAeroCaptionButtons="False"/></WindowChrome.WindowChrome>
 <Window.Resources>
  <Style TargetType="Button"><Setter Property="Background" Value="Transparent"/><Setter Property="BorderThickness" Value="0"/><Setter Property="Foreground" Value="#687568"/><Setter Property="Padding" Value="6,3"/><Setter Property="Cursor" Value="Hand"/><Setter Property="FontSize" Value="11"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border Background="{TemplateBinding Background}" CornerRadius="5" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#E1E6D4"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
  <Style TargetType="ProgressBar"><Setter Property="Height" Value="4"/><Setter Property="BorderThickness" Value="0"/><Setter Property="Background" Value="#E0E4D5"/><Setter Property="Foreground" Value="#81956C"/></Style>
 </Window.Resources>
 <Border Background="#F5F5E9" BorderBrush="#D9DEC9" BorderThickness="1" CornerRadius="9" Padding="12,10">
  <Grid><Grid.RowDefinitions><RowDefinition Height="46"/><RowDefinition Height="*"/></Grid.RowDefinitions>
<Grid x:Name="TitleBar" Background="Transparent"><Grid.RowDefinitions><RowDefinition Height="24"/><RowDefinition/></Grid.RowDefinitions><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="22"/><ColumnDefinition Width="22"/></Grid.ColumnDefinitions><StackPanel Orientation="Horizontal"><Image RenderOptions.BitmapScalingMode="HighQuality" Source="mascot-title.png" Width="27" Height="27" Margin="0,-1,7,0"/><TextBlock Text="Codex" FontSize="15" FontWeight="SemiBold"/></StackPanel><TextBlock x:Name="Plan" Grid.Column="1" Foreground="#81956C" Margin="0,3,8,0"/><Button x:Name="Pin" Grid.Column="2" Content="已置顶" VerticalAlignment="Top"/><Button x:Name="Minimize" Grid.Column="3" Content="−" ToolTip="收起到托盘" VerticalAlignment="Top"/><Button x:Name="Close" Grid.Column="4" Content="×" ToolTip="隐藏到托盘，右键退出" VerticalAlignment="Top"/><TextBlock x:Name="Status" Grid.Row="1" Grid.ColumnSpan="5" Text="更新 —" Foreground="#98A08E" FontSize="12"/></Grid>
<ScrollViewer x:Name="Body" Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Margin="0,6,0,0"><StackPanel>
<Grid Height="43" Margin="0,0,0,2"><TextBlock Text="5 小时"/><TextBlock x:Name="FiveValue" Text="—" HorizontalAlignment="Right" FontWeight="SemiBold"/><ProgressBar x:Name="FiveBar" Margin="0,19,0,0" VerticalAlignment="Top"/><TextBlock x:Name="FiveReset" Text="读取中" FontSize="12" Foreground="#8C9587" Margin="0,26,0,0"/></Grid>
<Grid Height="43" Margin="0,0,0,2"><TextBlock Text="本周"/><TextBlock x:Name="WeekValue" Text="—" HorizontalAlignment="Right" FontWeight="SemiBold"/><ProgressBar x:Name="WeekBar" Margin="0,19,0,0" VerticalAlignment="Top"/><TextBlock x:Name="WeekReset" FontSize="12" Foreground="#8C9587" Margin="0,26,0,0"/></Grid>
<Grid Height="54" Margin="0,0,0,0"><Grid.RowDefinitions><RowDefinition Height="27"/><RowDefinition Height="27"/></Grid.RowDefinitions><TextBlock Text="消耗" FontSize="13" FontWeight="SemiBold"/><TextBlock x:Name="Rate" Text="采样中" HorizontalAlignment="Right" FontSize="13" FontWeight="SemiBold"/><TextBlock Text="预计可用" Grid.Row="1" FontSize="13" FontWeight="SemiBold"/><TextBlock x:Name="Eta" Text="采样中" FontSize="14" FontWeight="SemiBold" Grid.Row="1" HorizontalAlignment="Right"/></Grid>
<Border BorderBrush="#E0E4D5" BorderThickness="0" Padding="0,0" Margin="0,0,0,5"><StackPanel><TextBlock x:Name="ResetInfo" Text="额外重置 · 查询中"/></StackPanel></Border>
<Grid Height="38" Margin="0,2,0,0" ToolTip="今日 token · 本机日志统计"><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions><StackPanel><TextBlock Text="缓存命中" Foreground="#8C9587" FontSize="12"/><TextBlock x:Name="CacheHit" Text="—" FontWeight="SemiBold" FontSize="14" Margin="0,2,0,0"/></StackPanel><StackPanel Grid.Column="1"><TextBlock Text="未命中" Foreground="#8C9587" FontSize="12"/><TextBlock x:Name="CacheMiss" Text="—" FontWeight="SemiBold" FontSize="14" Margin="0,2,0,0"/></StackPanel><StackPanel Grid.Column="2"><TextBlock Text="缓存命中率" Foreground="#8C9587" FontSize="12"/><TextBlock x:Name="CacheRate" Text="—" FontWeight="SemiBold" FontSize="14" Margin="0,2,0,0"/></StackPanel><StackPanel Grid.Column="3" HorizontalAlignment="Right"><TextBlock Text="输出" Foreground="#8C9587" FontSize="12"/><TextBlock x:Name="OutputTokens" Text="—" FontWeight="SemiBold" FontSize="14" Margin="0,2,0,0"/></StackPanel></Grid>
<Grid Height="66" Margin="0,3,0,3"><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions><Border Background="#ECEEDF" CornerRadius="7" Padding="10,7" Margin="0,0,4,0"><StackPanel><TextBlock Text="今日" Foreground="#8C9587" FontSize="12"/><TextBlock x:Name="TodayTotal" Text="—" FontSize="16" FontWeight="SemiBold"/><TextBlock x:Name="TodayCost" Text="$—" FontSize="12" Foreground="#81956C"/></StackPanel></Border><Border Grid.Column="1" Background="#ECEEDF" CornerRadius="7" Padding="10,7" Margin="4,0,0,0"><StackPanel><TextBlock Text="本月" Foreground="#8C9587" FontSize="12"/><TextBlock x:Name="MonthTotal" Text="—" FontSize="16" FontWeight="SemiBold"/><TextBlock x:Name="MonthCost" Text="$—" FontSize="12" Foreground="#81956C"/></StackPanel></Border></Grid>
<Grid Height="34" Margin="0,0,0,4"><TextBlock Text="输出速度" VerticalAlignment="Center" FontSize="13" FontWeight="SemiBold"/><TextBlock x:Name="Speed" Text="—" HorizontalAlignment="Right" VerticalAlignment="Center" FontSize="15" FontWeight="SemiBold" Foreground="#537443" ToolTip="输出速度 · 近60秒均值"/></Grid>
<Grid Margin="0,0,0,3"><TextBlock Text="最近会话" Foreground="#8C9587"/><TextBlock x:Name="Running" Text="—" HorizontalAlignment="Right" Foreground="#81956C" FontSize="12" ToolTip="根据本机日志估计，非官方实时状态"/></Grid>
<StackPanel x:Name="Sessions"/>
</StackPanel></ScrollViewer>
<ResizeGrip Grid.Row="1" HorizontalAlignment="Right" VerticalAlignment="Bottom" Width="12" Height="12" WindowChrome.ResizeGripDirection="BottomRight" Opacity="0.45"/>
</Grid>
 </Border>
</Window>
'@
$xaml.SelectSingleNode("//*[local-name()='Image']").SetAttribute('Source',(Join-Path $PSScriptRoot 'mascot-title.png'))
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$controls = @{}
foreach ($name in @('TitleBar','Pin','Minimize','Close','FiveValue','FiveBar','FiveReset','WeekValue','WeekBar','WeekReset','Rate','Eta','CacheHit','CacheMiss','CacheRate','OutputTokens','Speed','Status','Plan','ResetInfo','Running','Sessions','TodayTotal','MonthTotal','TodayCost','MonthCost')) { $controls[$name] = $window.FindName($name) }
$workArea = [System.Windows.SystemParameters]::WorkArea
$window.Left = $workArea.Right - $window.Width - 24
$window.Top = $workArea.Top + 60
try {
 if ((-not $SelfTest) -and (Test-Path -LiteralPath $settingsPath)) {
  $saved = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
  if ($saved.width -ge $window.MinWidth) { $window.Width = [Math]::Min([double]$saved.width, $workArea.Width) }
  if ($saved.height -ge $window.MinHeight) { $window.Height = [Math]::Min([double]$saved.height, $workArea.Height) }
  $window.Left = [Math]::Max($workArea.Left, [Math]::Min([double]$saved.left, $workArea.Right - $window.Width))
  $window.Top = [Math]::Max($workArea.Top, [Math]::Min([double]$saved.top, $workArea.Bottom - $window.Height))
  $window.Topmost = [bool]$saved.pinned
  if ($saved.layoutVersion -lt 160) { $window.Width = 352; $window.Height = 570 }
 }
} catch {}
function Update-Pin {
 $controls.Pin.Content = if ($window.Topmost) { '已置顶' } else { '置顶' }
 $controls.Pin.Foreground = if ($window.Topmost) { [Windows.Media.BrushConverter]::new().ConvertFromString('#537443') } else { [Windows.Media.Brushes]::Gray }
 if ($trayPin) { $trayPin.Checked = $window.Topmost }
 Save-WidgetSettings
}
function Save-WidgetSettings {
 if (-not $SelfTest) { try { @{layoutVersion=160;left=$window.Left;top=$window.Top;width=$window.Width;height=$window.Height;pinned=$window.Topmost} | ConvertTo-Json | Set-Content -LiteralPath $settingsPath -Encoding UTF8 } catch {} }
}
function Hide-Widget { Save-WidgetSettings; $window.Hide() }
function Show-Widget { $window.Show(); $window.WindowState = 'Normal'; $null = $window.Activate() }
function Toggle-Widget { if ($window.IsVisible) { Hide-Widget } else { Show-Widget } }
$script:exiting = $false
$app = New-Object Windows.Application
$app.ShutdownMode = 'OnExplicitShutdown'
$trayMenu = New-Object Windows.Forms.ContextMenuStrip
$trayToggle = $trayMenu.Items.Add('显示 / 隐藏便签')
$trayPin = $trayMenu.Items.Add('置顶')
$null = $trayMenu.Items.Add([Windows.Forms.ToolStripSeparator]::new())
$trayExit = $trayMenu.Items.Add('退出')
$trayToggle.Add_Click({ Toggle-Widget })
$trayPin.Add_Click({ $window.Topmost = -not $window.Topmost; Update-Pin })
$trayExit.Add_Click({ $script:exiting = $true; $window.Close(); $app.Shutdown() })
$trayIcon = New-Object Windows.Forms.NotifyIcon
# Create a small C icon using the same palette as the note.
$iconBitmap = [Drawing.Bitmap]::new(32,32)
$iconCanvas = [Drawing.Graphics]::FromImage($iconBitmap)
$iconCanvas.SmoothingMode = 'AntiAlias'
$iconBrush = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(83,116,67))
$iconFont = [Drawing.Font]::new('Segoe UI',20,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel)
$iconCanvas.FillEllipse($iconBrush,1,1,30,30)
$iconCanvas.DrawString('C',$iconFont,[Drawing.Brushes]::White,6,2)
$pngStream = [IO.MemoryStream]::new()
$iconBitmap.Save($pngStream,[Drawing.Imaging.ImageFormat]::Png)
$pngBytes = $pngStream.ToArray()
$icoStream = [IO.MemoryStream]::new()
$icoWriter = [IO.BinaryWriter]::new($icoStream)
$icoWriter.Write([uint16]0); $icoWriter.Write([uint16]1); $icoWriter.Write([uint16]1)
$icoWriter.Write([byte]32); $icoWriter.Write([byte]32); $icoWriter.Write([byte]0); $icoWriter.Write([byte]0)
$icoWriter.Write([uint16]1); $icoWriter.Write([uint16]32); $icoWriter.Write([uint32]$pngBytes.Length); $icoWriter.Write([uint32]22); $icoWriter.Write([byte[]]$pngBytes)
$icoStream.Position = 0
$trayGraphic = [Drawing.Icon]::new($icoStream)
$trayGraphic.Dispose(); $trayGraphic = [Drawing.Icon]::new((Join-Path $PSScriptRoot 'mascot.ico'))
$trayIcon.Icon = $trayGraphic
$trayIcon.Text = 'Codex 用量 · 单击显示/隐藏'
$trayIcon.ContextMenuStrip = $trayMenu
$trayIcon.Add_MouseClick({ param($sender,$e) if ($e.Button -eq [Windows.Forms.MouseButtons]::Left) { Toggle-Widget } })
$trayIcon.Visible = -not $SelfTest
Update-Pin
$controls.Pin.Add_Click({ $window.Topmost = -not $window.Topmost; Update-Pin })
$controls.Minimize.Add_Click({ Hide-Widget })
$controls.Close.Add_Click({ Hide-Widget })
$controls.TitleBar.Add_MouseLeftButtonDown({ param($sender,$e) if ($e.OriginalSource -is [System.Windows.Controls.TextBlock] -or $e.OriginalSource -eq $controls.TitleBar) { $window.DragMove() } })
function Format-Compact($n) {
 if ($null -eq $n) { return '—' }
 if ($n -ge 1000000) { return ('{0:0.00}M' -f ($n / 1000000)) }
 if ($n -ge 1000) { return ('{0:0.0}K' -f ($n / 1000)) }
 return ('{0:0}' -f $n)
}
function Format-Age($stamp) {
 if (-not $stamp) { return '时间未知' }
 $seconds = [Math]::Max(0,([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()-[long]$stamp)/1000)
 if ($seconds -lt 60) { return '刚刚' }; if ($seconds -lt 3600) { return ([int]($seconds/60)).ToString() + '分钟前' }; if ($seconds -lt 86400) { return ([int]($seconds/3600)).ToString() + '小时前' }; return ([int]($seconds/86400)).ToString() + '天前'
}
function Update-Sessions($sessions) {
 $controls.Sessions.Children.Clear()
 foreach ($session in @($sessions | Sort-Object @{Expression='running';Descending=$true},@{Expression='updatedAt';Descending=$true} | Select-Object -First 3)) {
  $row = [Windows.Controls.Grid]::new(); $row.Margin = '0,0,0,4'
  foreach ($i in 0..1) { $definition = [Windows.Controls.RowDefinition]::new(); $definition.Height = 'Auto'; $row.RowDefinitions.Add($definition) }
  $left = [Windows.Controls.ColumnDefinition]::new(); $left.Width = [Windows.GridLength]::new(1,[Windows.GridUnitType]::Star); $row.ColumnDefinitions.Add($left)
  $right = [Windows.Controls.ColumnDefinition]::new(); $right.Width = [Windows.GridLength]::new(76); $row.ColumnDefinitions.Add($right)
  $stack = [Windows.Controls.StackPanel]::new()
  $title = [Windows.Controls.TextBlock]::new(); $title.Text = $(if ($session.running) { '● ' } else { '· ' }) + $session.title; $title.TextTrimming = 'CharacterEllipsis'; $title.ToolTip = $session.title
  $meta = [Windows.Controls.TextBlock]::new(); $meta.Text = $session.model + ' · ' + (Format-Age $session.updatedAt); $meta.FontSize = 11; $meta.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#98A08E'); $meta.TextTrimming = 'CharacterEllipsis'
  $stack.Children.Add($title) | Out-Null; $stack.Children.Add($meta) | Out-Null
  $numbers = [Windows.Controls.StackPanel]::new(); $numbers.HorizontalAlignment = 'Right'; [Windows.Controls.Grid]::SetColumn($numbers,1)
  $total = [Windows.Controls.TextBlock]::new(); $total.Text = Format-Compact $session.tokens; $total.HorizontalAlignment = 'Right'; $total.FontWeight = 'SemiBold'; $total.ToolTip = ([long]$session.tokens).ToString('N0') + ' token · 此会话本机累计'
  $context = [Windows.Controls.TextBlock]::new(); $context.Text = if ($null -ne $session.contextTokens -and $null -ne $session.contextPercent) { '上下文 token {0:N0}，{1:0}%' -f $session.contextTokens,$session.contextPercent } else { '上下文 token —，—%' }; $context.FontSize = 11; $context.Foreground = $meta.Foreground; $context.HorizontalAlignment = 'Right'; [Windows.Controls.Grid]::SetRow($context,1); [Windows.Controls.Grid]::SetColumnSpan($context,2)
  $context.ToolTip = '上次请求token与上下文窗口之比，仅为估计'
  $amount = [Windows.Controls.TextBlock]::new(); $amount.Text = '${0:0.00}' -f $session.estimatedUsd; $amount.HorizontalAlignment = 'Right'; $amount.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#81956C'); $amount.FontSize = 11
  $numbers.Children.Add($total) | Out-Null; $numbers.Children.Add($amount) | Out-Null
  $row.Children.Add($stack) | Out-Null; $row.Children.Add($numbers) | Out-Null; $row.Children.Add($context) | Out-Null; $controls.Sessions.Children.Add($row) | Out-Null
 }
 if (-not $controls.Sessions.Children.Count) { $empty = [Windows.Controls.TextBlock]::new(); $empty.Text = '等待本机会话记录…'; $controls.Sessions.Children.Add($empty) | Out-Null }
}
function Update-Quota($w, $value, $bar, $resetText, $weekly) {
 if ($null -eq $w) { $value.Text = '—'; $bar.Value = 0; $resetText.Text = '暂无数据'; return }
 $value.Text = ('已用 {0:0.#}%' -f $w.used); $bar.Value = $w.used
 $bar.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString($(if ($w.used -ge 90) { '#CA7966' } elseif ($w.used -ge 70) { '#BA9C57' } else { '#81956C' }))
 $reset = [DateTimeOffset]::FromUnixTimeMilliseconds([long]$w.reset).LocalDateTime
 $resetText.Text = if ($w.expired) { '等待新窗口' } elseif ($weekly) { '重置 ' + $reset.ToString('MM/dd HH:mm') } else { '重置 ' + $reset.ToString('HH:mm') }
}
function Refresh-Widget {
 try {
  $s = Invoke-RestMethod 'http://127.0.0.1:47831/api/status' -TimeoutSec 2
  $bucket = @($s.buckets | Where-Object { $_.id -eq 'codex' }) | Select-Object -First 1
  if (-not $bucket) { $bucket = $s.buckets | Where-Object { $_.primary -or $_.secondary } | Select-Object -First 1 }
  Update-Quota $bucket.primary $controls.FiveValue $controls.FiveBar $controls.FiveReset $false
  Update-Quota $bucket.secondary $controls.WeekValue $controls.WeekBar $controls.WeekReset $true
  $rates = @(); $etas = @(); $tips = @()
  foreach ($pair in @(@('5h',$bucket.primary), @('周',$bucket.secondary))) {
   $w = $pair[1]
   $rate = if ($null -ne $w.rate) { '{0:0.##}%/h' -f $w.rate } else { '—' }
   $rates += ($pair[0] + ' ' + $rate)
   if ($w -and -not $w.expired -and $null -ne $w.etaHours) {
    if ([double]$w.etaHours -eq 0) { $etas += [double]0 }
    elseif (([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() + $w.etaHours * 3600000) -lt $w.reset) { $etas += [double]$w.etaHours }
    else { $tips += $pair[0] }
   }
  }
  $controls.Rate.Text = $rates -join ' · '
  $controls.Rate.ToolTip = '百分点/小时；5小时和周额度分别计算'
  $controls.Eta.Text = if ($etas.Count) { $hours = ($etas | Measure-Object -Minimum).Minimum; if ($hours -le 0) { '额度已用尽' } elseif ($hours -lt 1) { '约 ' + [Math]::Ceiling($hours * 60) + ' 分钟' } else { '约 {0:0.0} 小时' -f $hours } } elseif ($tips.Count -eq 2) { '预计先重置' } else { '采样中' }
  $controls.Eta.ToolTip = '取预计最先耗尽的额度。样本不足时显示采样中；不保证实际可用时长。'
  $hit = [long]$s.today.cached_input_tokens
  $miss = [Math]::Max(0, [long]$s.today.input_tokens - $hit)
  $controls.CacheHit.Text = Format-Compact $hit
  $controls.CacheMiss.Text = Format-Compact $miss
  $controls.CacheRate.Text = if ($s.today.input_tokens -gt 0) { '{0:0.0}%' -f (100.0*$hit/$s.today.input_tokens) } else { '—' }
  $controls.OutputTokens.Text = Format-Compact $s.today.output_tokens
  $controls.CacheHit.ToolTip = '今日缓存命中输入：' + $hit.ToString('N0') + ' token'
  $controls.CacheMiss.ToolTip = '今日未命中输入：' + $miss.ToString('N0') + ' token（输入减去缓存命中）'
  $controls.OutputTokens.ToolTip = '今日输出：' + ([long]$s.today.output_tokens).ToString('N0') + ' token（包含推理）'
  $controls.Speed.Text = ('{0:0.0} t/s' -f $s.speed.output)
  $updated = if ($bucket.updatedAt) { [DateTimeOffset]::FromUnixTimeMilliseconds([long]$bucket.updatedAt).LocalDateTime } else { $null }
  $queryAt = [Math]::Max([long]$bucket.updatedAt, [long]$s.refresh.lastSuccess)
  $controls.Plan.Text = if ($bucket.plan) { (Get-Culture).TextInfo.ToTitleCase([string]$bucket.plan) } else { '—' }
  $controls.TodayTotal.Text = Format-Compact $s.today.total_tokens
  $controls.MonthTotal.Text = Format-Compact $s.month.total_tokens
  $controls.TodayCost.Text = '${0:0.00}' -f $s.today.estimated_usd
  $controls.MonthCost.Text = '${0:0.00}' -f $s.month.estimated_usd
  $controls.MonthTotal.ToolTip = '本月本机保留日志的输入+输出，含缓存；不代表账户账单'
  $controls.Running.Text = '约 ' + [int]$s.runningCount + ' 个运行中'
  Update-Sessions $s.sessions
  $resetCredits = $bucket.resetCredits
  $controls.ResetInfo.Text = if ($null -ne $resetCredits.count) { '额外重置 · ' + $resetCredits.count + ' 次可用' } else { '额外重置 · 暂无数据' }
  if ($resetCredits.expiresAt) { $controls.ResetInfo.Text += ' · ' + [DateTimeOffset]::FromUnixTimeSeconds([long]$resetCredits.expiresAt).LocalDateTime.ToString('MM/dd') + ' 到期' }
  elseif ($resetCredits.count -gt 0) { $controls.ResetInfo.Text += ' · 到期时间未知' }
  $controls.ResetInfo.ToolTip = if ($resetCredits.expiryCached) { '本次接口只返回次数；日期保留自最近一次完整查询。' } else { '显示最早一笔额外重置的到期日期。' }
  $controls.Status.Text = if ($queryAt -gt 0) { '更新 ' + [DateTimeOffset]::FromUnixTimeMilliseconds($queryAt).LocalDateTime.ToString('HH:mm:ss') } else { '更新 —' }
  $controls.Status.ToolTip = if ($s.refresh.error) { $s.refresh.error + '；显示上次成功查询时间。' } else { '使用时随日志更新；停止使用10分钟后主动查询。' }
 } catch { $controls.Status.ToolTip = '本地服务未连接；保留上次查询时间。' }
}
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(5)
$timer.Add_Tick({ Refresh-Widget })
$window.Add_Loaded({ Refresh-Widget; $timer.Start() })
$window.Add_ContentRendered({
 if ($SelfTest) {
  if ($window.ShowInTaskbar) { throw 'Widget should not appear in taskbar' }
  $controls.Close.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
  if ($window.IsVisible -or -not $timer.IsEnabled) { throw 'Close should hide and keep monitoring' }
  Show-Widget
  $trayToggle.PerformClick()
  if ($window.IsVisible) { throw 'Tray hide failed' }
  $trayToggle.PerformClick()
  if (-not $window.IsVisible) { throw 'Tray show failed' }
  $trayPin.PerformClick()
  if ($trayPin.Checked -ne $window.Topmost) { throw 'Tray pin state out of sync' }
  $trayPin.PerformClick()
  $chrome = [System.Windows.Shell.WindowChrome]::GetWindowChrome($window)
  if ($chrome.ResizeBorderThickness.Left -lt 4 -or $window.ResizeMode -ne 'CanResizeWithGrip') { throw 'Resize border unavailable' }
  $defaultWidth = $window.Width; $defaultHeight = $window.Height
  $window.Width = $window.MinWidth; $window.Height = $window.MinHeight
  $window.UpdateLayout()
  foreach ($name in @('Pin','Close','Status')) {
   $control = $controls[$name]
   $point = $control.TranslatePoint([Windows.Point]::new(0,0),$window.Content)
   if ($point.Y -lt 0 -or ($point.Y + $control.ActualHeight) -gt $window.Content.ActualHeight + 1 -or ($point.X + $control.ActualWidth) -gt $window.Content.ActualWidth + 1) { throw "Control clipped at minimum size: $name" }
  }
  $window.Width = $defaultWidth; $window.Height = $defaultHeight
  $window.UpdateLayout()
  if ($window.FindName('Body').ScrollableHeight -gt 1) { throw 'Default window should fit without scrollbar' }
  $original = $window.Topmost
  $controls.Pin.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
  if ($window.Topmost -eq $original) { throw 'Pin toggle failed' }
  $controls.Pin.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
  if ($window.Topmost -ne $original) { throw 'Pin restore failed' }
 }
 if ($PreviewPath) {
  $window.UpdateLayout()
  $bitmap = [Windows.Media.Imaging.RenderTargetBitmap]::new([int]$window.ActualWidth, [int]$window.ActualHeight, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
  $bitmap.Render($window.Content)
  $encoder = [Windows.Media.Imaging.PngBitmapEncoder]::new()
  $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
  $imageStream = [IO.File]::Create($PreviewPath)
  try { $encoder.Save($imageStream) } finally { $imageStream.Dispose() }
 }
 if ($SelfTest) { $script:exiting = $true; $window.Close(); $app.Shutdown() } else { $null = $window.Activate() }
})
$window.Add_Closing({
 param($sender,$e)
 Save-WidgetSettings
 if (-not $script:exiting) { $e.Cancel = $true; $window.Hide(); return }
 $timer.Stop()
})
$app.Add_SessionEnding({ $script:exiting = $true })
try { $null = $app.Run($window) } finally {
 $trayIcon.Visible = $false; $trayIcon.Dispose(); $trayMenu.Dispose()
 $trayGraphic.Dispose(); $icoWriter.Dispose(); $icoStream.Dispose(); $pngStream.Dispose()
 $iconCanvas.Dispose(); $iconBitmap.Dispose(); $iconBrush.Dispose(); $iconFont.Dispose()
 $widgetMutex.ReleaseMutex(); $widgetMutex.Dispose()
}
