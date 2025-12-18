<#
.SYNOPSIS
    Maak een kleinere sample van een groot JSON-bestand.

.DESCRIPTION
    Dit script leest een JSON-array (of line-delimited JSON),
    extraheert de eerste N records en schrijft ze naar een nieuw JSON-array.
    Handig voor Spark of testdoeleinden in devcontainers.

.PARAMETER Path
    Pad naar het bronbestand (.json).

.PARAMETER OutFile
    Pad naar het uitvoerbestand (.json).

.PARAMETER Count
    Aantal records om te behouden (default: 1000).

.EXAMPLE
    .\make-json-sample.ps1 -Path data.json -OutFile sample.json -Count 500
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$OutFile,

    [int]$Count = 1000
)

if (-not (Test-Path $Path)) {
    Write-Error "❌ Bestand '$Path' bestaat niet."
    exit 1
}

Write-Host "📂 Bronbestand: $Path"
Write-Host "📦 Records behouden: $Count"
Write-Host "💾 Doelbestand: $OutFile"

# Test of jq aanwezig is
if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
    Write-Error "❌ jq is niet geïnstalleerd. Installeer via: choco install jq"
    exit 1
}

# Controleer of bestand begint met '[' (dus JSON-array)
$firstLine = Get-Content -Path $Path -TotalCount 1
$firstChar = $firstLine -match '^\s*\['

# Tijdelijk bestand
$tempFile = New-TemporaryFile

try {
    if ($firstChar) {
        Write-Host "🔄 Bestand is een JSON-array — converteren naar line-delimited JSON..."
        jq -c '.[]' $Path | Set-Content -Encoding utf8NoBOM $tempFile
    }
    else {
        Write-Host "ℹ️ Bestand lijkt al line-delimited JSON te zijn."
        Copy-Item $Path $tempFile -Force
    }

    Write-Host "✂️  Behouden van de eerste $Count regels..."
    $sampleLines = Get-Content -Path $tempFile -TotalCount $Count

    # Altijd terugschrijven als geldig JSON-array
    Write-Host "🧩 Schrijf sample weg als geldige JSON-array..."
    "[" | Out-File -FilePath $OutFile -Encoding utf8NoBOM
    ($sampleLines -join ",`n") | Out-File -FilePath $OutFile -Encoding utf8NoBOM -Append
    "]" | Out-File -FilePath $OutFile -Encoding utf8NoBOM -Append

    $origSize = (Get-Item $Path).Length / 1MB
    $newSize  = (Get-Item $OutFile).Length / 1MB
    Write-Host "✅ Sample klaar!"
    Write-Host "   Grootte: $([math]::Round($newSize,2)) MB (origineel $([math]::Round($origSize,2)) MB)"
}
finally {
    Remove-Item $tempFile -ErrorAction SilentlyContinue
}
