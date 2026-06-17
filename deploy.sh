#!/bin/bash
# ============================================================
# deploy.sh — Full deployment script for ACS Email Demo
# Deploys Azure infrastructure + application code
# ============================================================
# Usage:
#   chmod +x deploy.sh
#   ./deploy.sh <custom-domain> [resource-group] [location] [prefix]
#
# Example:
#   ./deploy.sh notifications.contoso.com rg-acs-email-demo eastus acsemail
# ============================================================

set -e

# ---- Parameters ----
CUSTOM_DOMAIN="${1:?ERROR: Custom domain required. Usage: ./deploy.sh <custom-domain> [resource-group] [location] [prefix]}"
RESOURCE_GROUP="${2:-rg-acs-email-demo}"
LOCATION="${3:-eastus}"
PREFIX="${4:-acsemail}"
SENDER_USERNAME="${5:-noreply}"

echo "=============================================="
echo " ACS Email Demo — Full Deployment"
echo "=============================================="
echo " Custom Domain:  $CUSTOM_DOMAIN"
echo " Resource Group: $RESOURCE_GROUP"
echo " Location:       $LOCATION"
echo " Prefix:         $PREFIX"
echo " Sender:         ${SENDER_USERNAME}@${CUSTOM_DOMAIN}"
echo "=============================================="
echo ""

# ---- Step 1: Create Resource Group ----
echo "► Step 1: Creating resource group..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
echo "  ✓ Resource group '$RESOURCE_GROUP' ready"
echo ""

# ---- Step 2: Deploy Bicep Infrastructure ----
echo "► Step 2: Deploying Azure infrastructure (Bicep)..."
DEPLOYMENT_OUTPUT=$(az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/main.bicep \
  --parameters \
    projectPrefix="$PREFIX" \
    customEmailDomain="$CUSTOM_DOMAIN" \
    senderUsername="$SENDER_USERNAME" \
  --query "properties.outputs" \
  --output json)

# Parse outputs
BACKEND_APP=$(echo "$DEPLOYMENT_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['backendAppName']['value'])" 2>/dev/null || echo "$DEPLOYMENT_OUTPUT" | jq -r '.backendAppName.value')
FRONTEND_APP=$(echo "$DEPLOYMENT_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['frontendAppName']['value'])" 2>/dev/null || echo "$DEPLOYMENT_OUTPUT" | jq -r '.frontendAppName.value')
BACKEND_URL=$(echo "$DEPLOYMENT_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['backendUrl']['value'])" 2>/dev/null || echo "$DEPLOYMENT_OUTPUT" | jq -r '.backendUrl.value')
FRONTEND_URL=$(echo "$DEPLOYMENT_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['frontendUrl']['value'])" 2>/dev/null || echo "$DEPLOYMENT_OUTPUT" | jq -r '.frontendUrl.value')
ACS_ENDPOINT=$(echo "$DEPLOYMENT_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['communicationServiceEndpoint']['value'])" 2>/dev/null || echo "$DEPLOYMENT_OUTPUT" | jq -r '.communicationServiceEndpoint.value')
SENDER_ADDRESS=$(echo "$DEPLOYMENT_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['senderAddress']['value'])" 2>/dev/null || echo "$DEPLOYMENT_OUTPUT" | jq -r '.senderAddress.value')

echo "  ✓ Infrastructure deployed"
echo "    Backend App:  $BACKEND_APP"
echo "    Frontend App: $FRONTEND_APP"
echo "    ACS Endpoint: $ACS_ENDPOINT"
echo "    Sender:       $SENDER_ADDRESS"
echo ""

# ---- Step 3: Deploy Backend Code ----
echo "► Step 3: Deploying backend code..."
cd backend
rm -f backend-deploy.zip
zip -r backend-deploy.zip . -x "node_modules/*" -x ".env"
az webapp deploy \
  --resource-group "$RESOURCE_GROUP" \
  --name "$BACKEND_APP" \
  --src-path backend-deploy.zip \
  --type zip \
  --output none
rm -f backend-deploy.zip
cd ..
echo "  ✓ Backend deployed to $BACKEND_URL"
echo ""

# ---- Step 4: Update Frontend API URL and Deploy ----
echo "► Step 4: Deploying frontend code..."
# Create a temporary copy with the correct API URL
TEMP_DIR=$(mktemp -d)
cp -r frontend/* "$TEMP_DIR/"
sed -i "s|http://localhost:3001|$BACKEND_URL|g" "$TEMP_DIR/app.js"

cd "$TEMP_DIR"
rm -f frontend-deploy.zip
zip -r frontend-deploy.zip .
az webapp deploy \
  --resource-group "$RESOURCE_GROUP" \
  --name "$FRONTEND_APP" \
  --src-path frontend-deploy.zip \
  --type zip \
  --output none
cd -
rm -rf "$TEMP_DIR"
echo "  ✓ Frontend deployed to $FRONTEND_URL"
echo ""

# ---- Step 5: DNS Verification Instructions ----
echo "=============================================="
echo " ⚠️  MANUAL STEP REQUIRED: DNS Verification"
echo "=============================================="
echo ""
echo " Your custom domain '$CUSTOM_DOMAIN' has been added to ACS Email"
echo " but requires DNS verification before you can send emails."
echo ""
echo " Go to Azure Portal:"
echo "   1. Open the Email Communication Services resource"
echo "   2. Go to 'Provision domains' → click your domain"
echo "   3. Add the following DNS records to your domain registrar:"
echo ""
echo "   ┌─────────────────────────────────────────────────┐"
echo "   │ OWNERSHIP VERIFICATION (TXT record)             │"
echo "   │ SPF (TXT record)                                │"
echo "   │ DKIM (2x CNAME records)                         │"
echo "   └─────────────────────────────────────────────────┘"
echo ""
echo "   The exact values are shown in the Azure Portal."
echo ""
echo "   4. Click 'Verify' for each record type"
echo "   5. Once all verified, emails can be sent!"
echo ""
echo "=============================================="
echo " ✅ Deployment Summary"
echo "=============================================="
echo ""
echo "  Frontend URL: $FRONTEND_URL"
echo "  Backend URL:  $BACKEND_URL"
echo "  Health Check: $BACKEND_URL/api/health"
echo ""
echo "  After DNS verification, open the Frontend URL"
echo "  and send a test email!"
echo "=============================================="
