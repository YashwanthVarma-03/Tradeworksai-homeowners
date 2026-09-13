<#
Builds transparent, square PNGs from the supplied service artwork. The source
SVGs embed black-canvas PNG exports; this keeps only the light line-art and
preserves its antialiasing for Flutter's runtime category tint.
#>

param(
  [ValidateRange(1, 32)]
  [int] $Start = 1,
  [ValidateRange(1, 32)]
  [int] $End = 32
)

if ($Start -gt $End) {
  throw 'Start must not be greater than End.'
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

Add-Type -ReferencedAssemblies ([System.Drawing.Bitmap].Assembly.Location) -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class ServiceIconCleaner
{
    public static void Clean(byte[] source, string outputPath)
    {
        using (var stream = new MemoryStream(source))
        using (var decoded = new Bitmap(stream))
        using (var bitmap = new Bitmap(decoded.Width, decoded.Height, PixelFormat.Format32bppArgb))
        {
            using (var graphics = Graphics.FromImage(bitmap))
            {
                graphics.DrawImage(decoded, 0, 0, decoded.Width, decoded.Height);
            }

            var bounds = new Rectangle(0, 0, bitmap.Width, bitmap.Height);
            var data = bitmap.LockBits(bounds, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
            int minX = bitmap.Width, minY = bitmap.Height, maxX = -1, maxY = -1;
            try
            {
                int stride = Math.Abs(data.Stride);
                var pixels = new byte[stride * bitmap.Height];
                Marshal.Copy(data.Scan0, pixels, 0, pixels.Length);

                int cornerBrightness = Math.Max(pixels[0], Math.Max(pixels[1], pixels[2]));
                bool hasLightCanvas = cornerBrightness > 127;

                for (int y = 0; y < bitmap.Height; y++)
                {
                    int row = y * stride;
                    for (int x = 0; x < bitmap.Width; x++)
                    {
                        int offset = row + x * 4;
                        int brightness = Math.Max(pixels[offset], Math.Max(pixels[offset + 1], pixels[offset + 2]));
                        int alpha = hasLightCanvas
                            ? (brightness >= 227 ? 0 : Math.Min(255, (int)Math.Round((227 - brightness) / 227.0 * pixels[offset + 3])))
                            : (brightness <= 28 ? 0 : Math.Min(255, (int)Math.Round((brightness - 28) / 227.0 * pixels[offset + 3])));

                        pixels[offset] = 255;
                        pixels[offset + 1] = 255;
                        pixels[offset + 2] = 255;
                        pixels[offset + 3] = (byte)alpha;

                        if (alpha > 8)
                        {
                            minX = Math.Min(minX, x);
                            minY = Math.Min(minY, y);
                            maxX = Math.Max(maxX, x);
                            maxY = Math.Max(maxY, y);
                        }
                    }
                }

                Marshal.Copy(pixels, 0, data.Scan0, pixels.Length);
            }
            finally
            {
                bitmap.UnlockBits(data);
            }

            if (maxX < 0)
            {
                throw new InvalidDataException("No visible artwork remains after cleanup.");
            }

            int padding = Math.Max(12, (int)Math.Round(Math.Max(maxX - minX, maxY - minY) * 0.06));
            int left = Math.Max(0, minX - padding);
            int top = Math.Max(0, minY - padding);
            int right = Math.Min(bitmap.Width, maxX + padding + 1);
            int bottom = Math.Min(bitmap.Height, maxY + padding + 1);

            using (var artwork = bitmap.Clone(Rectangle.FromLTRB(left, top, right, bottom), PixelFormat.Format32bppArgb))
            {
                int side = Math.Max(artwork.Width, artwork.Height);
                using (var canvas = new Bitmap(side, side, PixelFormat.Format32bppArgb))
                using (var graphics = Graphics.FromImage(canvas))
                {
                    graphics.Clear(Color.Transparent);
                    graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    graphics.DrawImage(artwork, (side - artwork.Width) / 2, (side - artwork.Height) / 2, artwork.Width, artwork.Height);
                    canvas.Save(outputPath, ImageFormat.Png);
                }
            }
        }
    }
}
'@

$sourceDirectory = Join-Path $PSScriptRoot '..\assets\icons\services'
$outputDirectory = Join-Path $sourceDirectory 'clean'
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

foreach ($index in $Start..$End) {
  $sourcePath = Join-Path $sourceDirectory "$index.svg"
  $source = [System.IO.File]::ReadAllText($sourcePath)
  $match = [regex]::Match($source, 'data:(?<mime>image/[^;]+);base64,(?<data>[^"'']+)')

  if (-not $match.Success) {
    throw "No embedded PNG data found in $sourcePath"
  }

  [ServiceIconCleaner]::Clean(
    [Convert]::FromBase64String($match.Groups['data'].Value),
    (Join-Path $outputDirectory "$index.png")
  )
  Write-Output "Cleaned $index.svg"
}
