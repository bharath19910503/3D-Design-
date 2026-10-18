$HarPath    = "C:\Users\hp\OneDrive\Desktop\Varshith interior solution\Website code\3D Design\traffic.har"
$SaveFolder = "C:\Users\hp\OneDrive\Desktop\Varshith interior solution\Website code\3D Design\DownloadedFiles"

$harContent = Get-Content $HarPath -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Force -Path $SaveFolder | Out-Null

# Subfolders
$folders = @{
    "Images"  = Join-Path $SaveFolder "Images"
    "PDFs"    = Join-Path $SaveFolder "PDFs"
    "Scripts" = Join-Path $SaveFolder "Scripts"
    "Fonts"   = Join-Path $SaveFolder "Fonts"
    "Videos"  = Join-Path $SaveFolder "Videos"
    "Others"  = Join-Path $SaveFolder "Others"
}
$folders.Values | ForEach-Object { New-Item -ItemType Directory -Force -Path $_ | Out-Null }

function Classify-Bytes($bytes,$mimeType) {
    # Image signatures
    if ($bytes.Length -gt 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xD8) { return @(".jpg",$folders.Images) }
    elseif ($bytes.Length -gt 3 -and $bytes[0] -eq 0x89 -and $bytes[1] -eq 0x50 -and $bytes[2] -eq 0x4E -and $bytes[3] -eq 0x47) { return @(".png",$folders.Images) }
    elseif ($bytes.Length -gt 2 -and $bytes[0] -eq 0x47 -and $bytes[1] -eq 0x49 -and $bytes[2] -eq 0x46) { return @(".gif",$folders.Images) }
    # PDF
    elseif ([System.Text.Encoding]::ASCII.GetString($bytes,0,[Math]::Min(4,$bytes.Length)) -like "%PDF*") { return @(".pdf",$folders.PDFs) }
    # ZIP
    elseif ($bytes.Length -gt 3 -and $bytes[0] -eq 0x50 -and $bytes[1] -eq 0x4B) { return @(".zip",$folders.Others) }
    # Text-like
    elseif ([System.Text.Encoding]::UTF8.GetString($bytes) -match "^[\x20-\x7E\s]+$") { return @(".txt",$folders.Others) }
    else {
        # Use MIME type fallback
        switch -Regex ($mimeType) {
            "application/javascript" { return @(".js",$folders.Scripts) }
            "application/json" { return @(".json",$folders.Scripts) }
            "application/xml"  { return @(".xml",$folders.Scripts) }
            "text/css" { return @(".css",$folders.Scripts) }
            "font/woff" { return @(".woff",$folders.Fonts) }
            "font/ttf" { return @(".ttf",$folders.Fonts) }
            "video/mp4" { return @(".mp4",$folders.Videos) }
            default { return @(".bin",$folders.Others) }
        }
    }
}

$i = 1
$results = foreach ($entry in $harContent.log.entries) {
    $content = $entry.response.content
    if ($content.encoding -eq "base64" -and $content.text) {
        try {
            $bytes = [System.Convert]::FromBase64String($content.text)
            $ext,$folder = Classify-Bytes $bytes $content.mimeType
            $fileName = Join-Path $folder ("file$i$ext")
            [System.IO.File]::WriteAllBytes($fileName, $bytes)
            Write-Host "✅ Saved $fileName ($content.mimeType)"
            [PSCustomObject]@{File=$fileName;MimeType=$content.mimeType;Status="Success"}
        } catch {
            Write-Warning "⚠️ Failed to decode entry $i"
            [PSCustomObject]@{File="file$i";MimeType=$content.mimeType;Status="Failed"}
        }
        $i++
    }
}

if ($results) {
    $results | Export-Csv (Join-Path $SaveFolder "ClassifiedFilesLog.csv") -NoTypeInformation
    Write-Host "📄 Log saved to $SaveFolder\ClassifiedFilesLog.csv"
} else {
    Write-Host "⚠️ No base64 content found in HAR."
}
