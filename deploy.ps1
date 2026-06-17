# ============================================================
# deploy.ps1 — Full deployment script for ACS Email Demo (Windows)
# Deploys Azure infrastructure + application code
# ============================================================
# Usage:
#   .\deploy.ps1 -CustomDomain "notifications.contoso.com"
#   .\deploy.ps1 -CustomDomain "notifications.contoso.com" -ResourceGroup "my-rg" -Location "westus2"
# ============================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$CustomDomain,

    [string]$ResourceGroup = "rg-acs-email-demo",
    [string]$Location = "eastus",
    [string]$Prefix = "acsemail",
    [string]$SenderUsername = "noreply"
)

$ErrorActionPreference = "Stop"

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " ACS Email Demo - Full Deployment" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " Custom Domain:  $CustomDomain"
Write-Host " Resource Group: $ResourceGroup"
Write-Host " Location:       $Location"
Write-Host " Prefix:         $Prefix"
Write-Host " Sender:         ${SenderUsername}@${CustomDomain}"
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

# ---- Step 1: Create Resource Group ----
Write-Host ">> Step 1: Creating resource group..." -ForegroundColor Yellow
az group create --name $ResourceGroup --location $Location --output none
if ($LASTEXITCODE -ne 0) { throw "Failed to create resource group" }
Write-Host "   OK - Resource group '$ResourceGroup' ready" -ForegroundColor Green
Write-Host ""

# ---- Step 2: Deploy Bicep Infrastructure ----
Write-Host ">> Step 2: Deploying Azure infrastructure (Bicep)..." -ForegroundColor Yellow
$deploymentJson = az deployment group create `
    --resource-group $ResourceGroup `
    --template-file infra/main.bicep `
    --parameters projectPrefix=$Prefix customEmailDomain=$CustomDomain senderUsername=$SenderUsername `
    --query "properties.outputs" `
    --output json

if ($LASTEXITCODE -ne 0) { throw "Bicep deployment failed" }

$outputs = $deploymentJson | ConvertFrom-Json
$backendApp = $outputs.backendAppName.value
$frontendApp = $outputs.frontendAppName.value
$backendUrl = $outputs.backendUrl.value
$frontendUrl = $outputs.frontendUrl.value
$acsEndpoint = $outputs.communicationServiceEndpoint.value
$senderAddress = $outputs.senderAddress.value

Write-Host "   OK - Infrastructure deployed" -ForegroundColor Green
Write-Host "   Backend App:  $backendApp"
Write-Host "   Frontend App: $frontendApp"
Write-Host "   ACS Endpoint: $acsEndpoint"
Write-Host "   Sender:       $senderAddress"
Write-Host ""

# ---- Step 3: Deploy Backend Code ----
Write-Host ">> Step 3: Deploying backend code..." -ForegroundColor Yellow
Push-Location backend

# Create zip excluding node_modules and .env
if (Test-Path "backend-deploy.zip") { Remove-Item "backend-deploy.zip" }
$filesToZip = Get-ChildItem -Path . -Exclude "node_modules", ".env", "backend-deploy.zip" -Recurse
Compress-Archive -Path "server.js", "package.json", "package-lock.json" -DestinationPath "backend-deploy.zip" -Force

az webapp deploy `
    --resource-group $ResourceGroup `
    --name $backendApp `
    --src-path "backend-deploy.zip" `
    --type zip `
    --output none

if ($LASTEXITCODE -ne 0) { Pop-Location; throw "Backend deployment failed" }
Remove-Item "backend-deploy.zip" -ErrorAction SilentlyContinue
Pop-Location
Write-Host "   OK - Backend deployed to $backendUrl" -ForegroundColor Green
Write-Host ""

# ---- Step 4: Update Frontend API URL and Deploy ----
Write-Host ">> Step 4: Deploying frontend code..." -ForegroundColor Yellow
$tempDir = Join-Path $env:TEMP "acs-frontend-deploy-$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Copy-Item -Path "frontend\*" -Destination $tempDir -Recurse

# Replace localhost URL with actual backend URL
$appJsPath = Join-Path $tempDir "app.js"
$content = Get-Content $appJsPath -Raw
$content = $content.Replace("http://localhost:3001", $backendUrl)
Set-Content -Path $appJsPath -Value $content

# Create zip
$frontendZip = Join-Path $tempDir "frontend-deploy.zip"
Compress-Archive -Path "$tempDir\index.html", "$tempDir\styles.css", "$tempDir\app.js" -DestinationPath $frontendZip -Force

az webapp deploy `
    --resource-group $ResourceGroup `
    --name $frontendApp `
    --src-path $frontendZip `
    --type zip `
    --output none

if ($LASTEXITCODE -ne 0) { Remove-Item $tempDir -Recurse -Force; throw "Frontend deployment failed" }
Remove-Item $tempDir -Recurse -Force
Write-Host "   OK - Frontend deployed to $frontendUrl" -ForegroundColor Green
Write-Host ""

# ---- Step 5: DNS Verification Instructions ----
Write-Host "==============================================" -ForegroundColor Yellow
Write-Host " WARNING: MANUAL STEP REQUIRED" -ForegroundColor Yellow
Write-Host " DNS Verification for '$CustomDomain'" -ForegroundColor Yellow
Write-Host "==============================================" -ForegroundColor Yellow
Write-Host ""
Write-Host " Your domain has been added to ACS Email but needs DNS verification."
Write-Host ""
Write-Host " Go to Azure Portal:" -ForegroundColor White
Write-Host "   1. Open the Email Communication Services resource"
Write-Host "   2. Go to 'Provision domains' -> click your domain"
Write-Host "   3. Add the DNS records shown (TXT for ownership, TXT for SPF, CNAME for DKIM)"
Write-Host "   4. Click 'Verify' for each record type"
Write-Host "   5. Once all verified, you can send emails!"
Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host " DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Frontend URL: $frontendUrl" -ForegroundColor White
Write-Host "  Backend URL:  $backendUrl" -ForegroundColor White
Write-Host "  Health Check: $backendUrl/api/health" -ForegroundColor White
Write-Host ""
Write-Host "  After DNS verification, open the Frontend URL and send a test email!"
Write-Host ""
