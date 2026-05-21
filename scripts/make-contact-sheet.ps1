param(
  [string]$FramesRoot = "assets\frames",
  [string]$OutputPath = "tmp\frame-contact.png",
  [int]$CellWidth = 150,
  [int]$CellHeight = 128
)

Add-Type -AssemblyName System.Drawing

if (-not (Test-Path $FramesRoot)) {
  Write-Error "Missing frames directory: $FramesRoot"
  exit 1
}

$outputParent = Split-Path $OutputPath -Parent
if (-not [string]::IsNullOrWhiteSpace($outputParent)) {
  New-Item -ItemType Directory -Force -Path $outputParent | Out-Null
}

$font = New-Object System.Drawing.Font("Arial", 10)
$labelBrush = [System.Drawing.Brushes]::White
$bg = [System.Drawing.Color]::FromArgb(255, 12, 10, 24)
$actions = Get-ChildItem -LiteralPath $FramesRoot -Directory | Sort-Object Name
$labelHeight = 22
$gap = 10
$maxFrames = ($actions | ForEach-Object { @(Get-ChildItem -LiteralPath $_.FullName -Filter "*.png").Count } | Measure-Object -Maximum).Maximum

$width = [Math]::Max(900, $maxFrames * ($CellWidth + $gap) + $gap)
$height = $actions.Count * ($CellHeight + $labelHeight + $gap) + $gap
$bitmap = New-Object System.Drawing.Bitmap($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.Clear($bg)
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half

try {
  $row = 0
  foreach ($action in $actions) {
    $y = $gap + $row * ($CellHeight + $labelHeight + $gap)
    $graphics.DrawString($action.Name, $font, $labelBrush, 8, $y + 4)
    $files = Get-ChildItem -LiteralPath $action.FullName -Filter "*.png" | Sort-Object Name
    $column = 0

    foreach ($file in $files) {
      $image = [System.Drawing.Image]::FromFile($file.FullName)
      try {
        $scale = [Math]::Min(($CellWidth - 12) / $image.Width, ($CellHeight - 12) / $image.Height)
        $drawWidth = [int]($image.Width * $scale)
        $drawHeight = [int]($image.Height * $scale)
        $cellLeft = $gap + $column * ($CellWidth + $gap)
        $imageLeft = $cellLeft + [int](($CellWidth - $drawWidth) / 2)
        $imageTop = $y + $labelHeight + [int](($CellHeight - $drawHeight) / 2)

        $graphics.DrawRectangle([System.Drawing.Pens]::DimGray, $cellLeft, $y + $labelHeight, $CellWidth, $CellHeight)
        $graphics.DrawImage($image, $imageLeft, $imageTop, $drawWidth, $drawHeight)
        $graphics.DrawString($file.BaseName, $font, $labelBrush, $cellLeft + 4, $y + $labelHeight + 4)
      }
      finally {
        $image.Dispose()
      }
      $column++
    }
    $row++
  }

  $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
  Write-Host $OutputPath
}
finally {
  $graphics.Dispose()
  $bitmap.Dispose()
  $font.Dispose()
}
