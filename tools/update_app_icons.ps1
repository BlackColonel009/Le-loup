param([string]$Root = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$app = Join-Path $Root 'apps/le_loup'
$logo = [System.Drawing.Image]::FromFile((Join-Path $app 'assets/branding/logo.png'))
function Save-IconPng([string]$Path, [int]$Size, [bool]$Opaque = $false, [double]$Margin = 0) {
    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $background = if ($Opaque) { [System.Drawing.Color]::FromArgb(255,21,27,36) } else { [System.Drawing.Color]::Transparent }
        $graphics.Clear($background)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $edge = [int]($Size * $Margin)
        $graphics.DrawImage($logo, $edge, $edge, ($Size - 2*$edge), ($Size - 2*$edge))
        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
}
try {
    $densities = @{mdpi=48;hdpi=72;xhdpi=96;xxhdpi=144;xxxhdpi=192}
    foreach ($density in $densities.Keys) {
        Save-IconPng (Join-Path $app "android/app/src/main/res/mipmap-$density/ic_launcher.png") $densities[$density]
    }
    $ios = Join-Path $app 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    $catalog = Get-Content -Raw (Join-Path $ios 'Contents.json') | ConvertFrom-Json
    foreach ($entry in $catalog.images) {
        if ($entry.filename) {
            $size = [double]($entry.size.Split('x')[0]) * [double]($entry.scale.TrimEnd('x'))
            Save-IconPng (Join-Path $ios $entry.filename) ([int]$size) $true
        }
    }
    foreach ($size in @(192,512)) {
        Save-IconPng (Join-Path $app "web/icons/Icon-$size.png") $size $true
        Save-IconPng (Join-Path $app "web/icons/Icon-maskable-$size.png") $size $true .15
    }
    Save-IconPng (Join-Path $app 'web/favicon.png') 32 $true
    # PNG-compressed multi-resolution ICO, consumed by the Windows resource compiler.
    $sizes = @(16,32,48,256)
    $images = [System.Collections.Generic.List[byte[]]]::new()
    foreach ($size in $sizes) {
        $bitmap = [System.Drawing.Bitmap]::new($size,$size)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $stream = [System.IO.MemoryStream]::new()
        try {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.DrawImage($logo,0,0,$size,$size)
            $bitmap.Save($stream,[System.Drawing.Imaging.ImageFormat]::Png)
            $images.Add($stream.ToArray())
        } finally {$stream.Dispose();$graphics.Dispose();$bitmap.Dispose()}
    }
    $output = [System.IO.File]::Create((Join-Path $app 'windows/runner/resources/app_icon.ico'))
    $writer = [System.IO.BinaryWriter]::new($output)
    try {
        $writer.Write([uint16]0);$writer.Write([uint16]1);$writer.Write([uint16]$sizes.Count)
        $offset = 6 + 16*$sizes.Count
        for($i=0;$i -lt $sizes.Count;$i++) {
            $side = if($sizes[$i] -eq 256){0}else{$sizes[$i]}
            $writer.Write([byte]$side);$writer.Write([byte]$side)
            $writer.Write([byte]0);$writer.Write([byte]0)
            $writer.Write([uint16]1);$writer.Write([uint16]32)
            $writer.Write([uint32]$images[$i].Length);$writer.Write([uint32]$offset)
            $offset += $images[$i].Length
        }
        foreach($bytes in $images){$writer.Write([byte[]]$bytes)}
    } finally {$writer.Dispose();$output.Dispose()}
} finally {$logo.Dispose()}
Write-Output 'Icônes Android, iOS, Windows et Web mises à jour depuis le logo du projet.'
