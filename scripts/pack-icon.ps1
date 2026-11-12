$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$target=Join-Path (Split-Path $PSScriptRoot -Parent) 'app'
$source=[Drawing.Image]::FromFile((Join-Path $target 'mascot.png'))
$images=@()
foreach($size in @(16,24,32,48,64,256)){
 $bmp=[Drawing.Bitmap]::new($size,$size);$g=[Drawing.Graphics]::FromImage($bmp);$g.InterpolationMode='HighQualityBicubic';$g.CompositingQuality='HighQuality';$g.SmoothingMode='AntiAlias'
 $ratio=[Math]::Min($size/$source.Width,$size/$source.Height);$width=[int]($source.Width*$ratio);$height=[int]($source.Height*$ratio)
 $g.DrawImage($source,[int](($size-$width)/2),[int](($size-$height)/2),$width,$height)
 $stream=[IO.MemoryStream]::new();$bmp.Save($stream,[Drawing.Imaging.ImageFormat]::Png);$images+=,@{size=$size;bytes=$stream.ToArray()};if($size -eq 64){$bmp.Save((Join-Path $target 'mascot-title.png'),[Drawing.Imaging.ImageFormat]::Png)};$stream.Dispose();$g.Dispose();$bmp.Dispose()
}
$source.Dispose();$out=[IO.File]::Create((Join-Path $target 'mascot.ico'));$w=[IO.BinaryWriter]::new($out);$w.Write([uint16]0);$w.Write([uint16]1);$w.Write([uint16]$images.Count);$offset=6+16*$images.Count
foreach($item in $images){$dimension=if($item.size -eq 256){0}else{$item.size};$w.Write([byte]$dimension);$w.Write([byte]$dimension);$w.Write([byte]0);$w.Write([byte]0);$w.Write([uint16]1);$w.Write([uint16]32);$w.Write([uint32]$item.bytes.Length);$w.Write([uint32]$offset);$offset+=$item.bytes.Length}
foreach($item in $images){$w.Write([byte[]]$item.bytes)};$w.Dispose();$out.Dispose()
