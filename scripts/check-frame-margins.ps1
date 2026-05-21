param(
  [string]$FramesRoot = "assets\frames",
  [int]$Margin = 2
)

Add-Type -AssemblyName System.Drawing

if (-not (Test-Path $FramesRoot)) {
  Write-Error "Missing frames directory: $FramesRoot"
  exit 1
}

$errors = @()
$frameFiles = Get-ChildItem -LiteralPath $FramesRoot -Recurse -Filter "*.png" | Sort-Object FullName

foreach ($file in $frameFiles) {
  $bitmap = [System.Drawing.Bitmap]::FromFile($file.FullName)
  try {
    $found = $false
    for ($y = 0; $y -lt $bitmap.Height -and -not $found; $y++) {
      for ($x = 0; $x -lt $bitmap.Width; $x++) {
        $isMarginPixel = $x -lt $Margin -or $y -lt $Margin -or
          $x -ge ($bitmap.Width - $Margin) -or $y -ge ($bitmap.Height - $Margin)

        if ($isMarginPixel -and $bitmap.GetPixel($x, $y).A -gt 0) {
          $relativePath = Resolve-Path -Relative $file.FullName
          $errors += "$relativePath has visible pixels on transparent margin at ($x,$y)"
          $found = $true
          break
        }
      }
    }
  }
  finally {
    $bitmap.Dispose()
  }
}

if ($errors.Count -gt 0) {
  Write-Error ($errors -join "; ")
  exit 1
}

Write-Host "OK: exported frames keep transparent margins without edge fragments."
