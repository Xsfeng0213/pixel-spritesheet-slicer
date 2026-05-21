param(
  [string]$SourcePath = "",
  [Parameter(Mandatory = $true)]
  [string]$PlanPath,
  [string]$OutputDir = "assets\frames"
)

Add-Type -AssemblyName System.Drawing

function Test-TransparentBackgroundPixel {
  param([System.Drawing.Color]$Color)
  return $Color.A -lt 16 -or ($Color.R -gt 236 -and $Color.G -gt 236 -and $Color.B -gt 232)
}

function Find-Components {
  param([System.Drawing.Bitmap]$Bitmap)

  $width = $Bitmap.Width
  $height = $Bitmap.Height
  $visited = New-Object 'bool[,]' $width, $height
  $components = New-Object System.Collections.Generic.List[object]

  for ($top = 0; $top -lt $height; $top++) {
    for ($left = 0; $left -lt $width; $left++) {
      if ($visited[$left, $top]) { continue }
      $visited[$left, $top] = $true
      if ($Bitmap.GetPixel($left, $top).A -eq 0) { continue }

      $queue = New-Object System.Collections.Generic.Queue[object]
      $pixels = New-Object System.Collections.Generic.List[object]
      $queue.Enqueue(@($left, $top))
      $minLeft = $left
      $maxLeft = $left
      $minTop = $top
      $maxTop = $top

      while ($queue.Count -gt 0) {
        $point = $queue.Dequeue()
        $pointLeft = [int]$point[0]
        $pointTop = [int]$point[1]
        $pixels.Add(@($pointLeft, $pointTop))

        if ($pointLeft -lt $minLeft) { $minLeft = $pointLeft }
        if ($pointLeft -gt $maxLeft) { $maxLeft = $pointLeft }
        if ($pointTop -lt $minTop) { $minTop = $pointTop }
        if ($pointTop -gt $maxTop) { $maxTop = $pointTop }

        foreach ($delta in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1))) {
          $nextLeft = $pointLeft + [int]$delta[0]
          $nextTop = $pointTop + [int]$delta[1]
          if ($nextLeft -lt 0 -or $nextTop -lt 0 -or $nextLeft -ge $width -or $nextTop -ge $height) { continue }
          if ($visited[$nextLeft, $nextTop]) { continue }
          $visited[$nextLeft, $nextTop] = $true
          if ($Bitmap.GetPixel($nextLeft, $nextTop).A -gt 0) {
            $queue.Enqueue(@($nextLeft, $nextTop))
          }
        }
      }

      if ($pixels.Count -gt 10) {
        $components.Add([PSCustomObject]@{
          pixels = $pixels
          area = $pixels.Count
          left = $minLeft
          top = $minTop
          right = $maxLeft
          bottom = $maxTop
          centerLeft = ($minLeft + $maxLeft) / 2.0
          centerTop = ($minTop + $maxTop) / 2.0
        })
      }
    }
  }

  return $components.ToArray()
}

function Export-Frame {
  param(
    [System.Drawing.Bitmap]$SourceBitmap,
    [object]$Frame,
    [int]$DefaultPadding,
    [string]$DestinationPath
  )

  $sourceRectangle = New-Object System.Drawing.Rectangle -ArgumentList $Frame.left, $Frame.top, $Frame.width, $Frame.height
  $crop = New-Object System.Drawing.Bitmap($Frame.width, $Frame.height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $cropGraphics = [System.Drawing.Graphics]::FromImage($crop)
  $cropGraphics.DrawImage($SourceBitmap, 0, 0, $sourceRectangle, [System.Drawing.GraphicsUnit]::Pixel)
  $cropGraphics.Dispose()

  try {
    for ($top = 0; $top -lt $crop.Height; $top++) {
      for ($left = 0; $left -lt $crop.Width; $left++) {
        $color = $crop.GetPixel($left, $top)
        if (Test-TransparentBackgroundPixel $color) {
          $crop.SetPixel($left, $top, [System.Drawing.Color]::Transparent)
        }
      }
    }

    $components = Find-Components $crop
    if ($components.Count -eq 0) {
      throw "No visible pixels found for $DestinationPath"
    }

    if ($Frame.keepAll -eq $true) {
      $selectedComponents = @($components)
    }
    else {
      $keepDistance = if ($Frame.keepDistance -ne $null) { [double]$Frame.keepDistance } else { 58.0 }
      $mainComponent = $components | Sort-Object area -Descending | Select-Object -First 1
      $selectedComponents = @()

      foreach ($component in $components) {
        $distance = [Math]::Sqrt(
          [Math]::Pow($component.centerLeft - $mainComponent.centerLeft, 2) +
          [Math]::Pow($component.centerTop - $mainComponent.centerTop, 2)
        )

        if ($component -eq $mainComponent -or $distance -le $keepDistance) {
          $selectedComponents += $component
        }
      }
    }

    $mask = New-Object 'bool[,]' $crop.Width, $crop.Height
    $minLeft = $crop.Width
    $minTop = $crop.Height
    $maxLeft = 0
    $maxTop = 0

    foreach ($component in $selectedComponents) {
      foreach ($pixel in $component.pixels) {
        $pixelLeft = [int]$pixel[0]
        $pixelTop = [int]$pixel[1]
        $mask[$pixelLeft, $pixelTop] = $true
        if ($pixelLeft -lt $minLeft) { $minLeft = $pixelLeft }
        if ($pixelLeft -gt $maxLeft) { $maxLeft = $pixelLeft }
        if ($pixelTop -lt $minTop) { $minTop = $pixelTop }
        if ($pixelTop -gt $maxTop) { $maxTop = $pixelTop }
      }
    }

    for ($top = 0; $top -lt $crop.Height; $top++) {
      for ($left = 0; $left -lt $crop.Width; $left++) {
        if (-not $mask[$left, $top]) {
          $crop.SetPixel($left, $top, [System.Drawing.Color]::Transparent)
        }
      }
    }

    $padding = if ($Frame.padding -ne $null) { [int]$Frame.padding } else { $DefaultPadding }
    $contentRectangle = New-Object System.Drawing.Rectangle -ArgumentList $minLeft, $minTop, ($maxLeft - $minLeft + 1), ($maxTop - $minTop + 1)
    $trimmed = New-Object System.Drawing.Bitmap(($contentRectangle.Width + $padding * 2), ($contentRectangle.Height + $padding * 2), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $trimmedGraphics = [System.Drawing.Graphics]::FromImage($trimmed)
    $trimmedGraphics.Clear([System.Drawing.Color]::Transparent)
    $trimmedGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $trimmedGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $trimmedGraphics.DrawImage($crop, $padding, $padding, $contentRectangle, [System.Drawing.GraphicsUnit]::Pixel)
    $trimmedGraphics.Dispose()

    try {
      $parentDir = Split-Path $DestinationPath -Parent
      New-Item -ItemType Directory -Force -Path $parentDir | Out-Null
      $trimmed.Save($DestinationPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
      $trimmed.Dispose()
    }
  }
  finally {
    $crop.Dispose()
  }
}

$plan = Get-Content -Raw -Encoding UTF8 $PlanPath | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($SourcePath)) {
  if ([string]::IsNullOrWhiteSpace($plan.source)) {
    throw "SourcePath is required when plan.source is not set."
  }
  $SourcePath = $plan.source
}

$sourceBitmap = [System.Drawing.Bitmap]::FromFile((Resolve-Path $SourcePath).Path)
$defaultPadding = if ($plan.padding -ne $null) { [int]$plan.padding } else { 8 }

try {
  New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
  $manifestActions = [ordered]@{}

  foreach ($actionProperty in $plan.actions.PSObject.Properties) {
    $actionName = $actionProperty.Name
    $action = $actionProperty.Value
    $actionDir = Join-Path $OutputDir $actionName

    if (Test-Path $actionDir) {
      Remove-Item -LiteralPath $actionDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $actionDir | Out-Null

    $relativeFrames = New-Object System.Collections.Generic.List[string]
    $frameIndex = 0
    foreach ($frame in @($action.frames)) {
      $fileName = "{0:D2}.png" -f $frameIndex
      $relativePath = Join-Path $actionName $fileName
      $destinationPath = Join-Path $OutputDir $relativePath
      Export-Frame -SourceBitmap $sourceBitmap -Frame $frame -DefaultPadding $defaultPadding -DestinationPath $destinationPath
      $relativeFrames.Add(($relativePath -replace "\\", "/"))
      $frameIndex++
    }

    $manifestAction = [ordered]@{
      speed = if ($action.speed -ne $null) { [int]$action.speed } else { 160 }
      frames = @($relativeFrames)
    }
    foreach ($optionalKey in @("once", "effect", "className")) {
      if ($action.PSObject.Properties.Name -contains $optionalKey) {
        $manifestAction[$optionalKey] = $action.$optionalKey
      }
    }
    $manifestActions[$actionName] = $manifestAction
  }

  $manifest = [ordered]@{
    source = $SourcePath
    actions = $manifestActions
  }
  $manifest | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 (Join-Path $OutputDir "manifest.json")
  Write-Host "Exported frame assets to $OutputDir"
}
finally {
  $sourceBitmap.Dispose()
}
