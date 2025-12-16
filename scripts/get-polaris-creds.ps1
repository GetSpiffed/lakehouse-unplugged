# Create scripts\get-polaris-creds.ps1
New-Item -ItemType Directory -Force -Path scripts
@'
$CREDS = docker logs polaris 2>&1 | Select-String "root principal credentials:"
if ($CREDS) {
    $PARTS = $CREDS -split ':'
    $CLIENT_ID = $PARTS[0] -replace '.*credentials: ', ''
    $CLIENT_SECRET = $PARTS[1]
    
    "@
POLARIS_CLIENT_ID=$CLIENT_ID
POLARIS_CLIENT_SECRET=$CLIENT_SECRET
"@ | Out-File -FilePath .\.env -Encoding utf8
    
    Write-Host "✅ Credentials extracted to .env"
} else {
    Write-Host "❌ Could not find Polaris credentials"
    exit 1
}
'@ | Out-File -FilePath scripts\get-polaris-creds.ps1 -Encoding utf8