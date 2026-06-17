# ACS Email Demo — Full-Stack Application

Send emails using **Azure Communication Services (ACS) Email** with a custom verified domain, secured by **Managed Identity** (no connection strings).

## Architecture

```
┌──────────────────┐        POST /api/send-email        ┌─────────────────────┐
│   Frontend       │  ─────────────────────────────────► │   Backend (Node.js) │
│   (HTML/JS/CSS)  │  ◄─────────────────────────────────  │   Express API       │
│   App Service    │         JSON response               │   App Service       │
└──────────────────┘                                     └────────┬────────────┘
                                                                  │
                                                                  │ DefaultAzureCredential
                                                                  │ (Managed Identity)
                                                                  ▼
                                                         ┌─────────────────────┐
                                                         │  Azure Communication│
                                                         │  Services Email     │
                                                         │  (Custom Domain)    │
                                                         └─────────────────────┘
```

## Folder Structure

```
ACS_Email/
├── infra/
│   ├── main.bicep        # Azure infrastructure (all resources)
│   └── parameters.json   # Deployment parameters template
├── deploy.ps1            # One-click deploy script (Windows/PowerShell)
├── deploy.sh             # One-click deploy script (Linux/macOS/bash)
├── frontend/
│   ├── index.html        # Email form UI
│   ├── styles.css        # Responsive styling
│   └── app.js            # Frontend logic (fetch to backend)
├── backend/
│   ├── server.js         # Express API with ACS Email SDK
│   ├── package.json      # Node.js dependencies
│   └── .env.example      # Required environment variables
└── README.md             # This file
```

---

## Prerequisites

- Node.js 18+
- Azure subscription
- Azure CLI (`az`) installed and logged in
- A **custom domain you own** with access to its DNS settings (e.g., `notifications.contoso.com`)

---

## 🚀 One-Click Deployment (Recommended)

The fastest way to deploy everything — infrastructure + code — in one command:

### Windows (PowerShell)

```powershell
az login
.\deploy.ps1 -CustomDomain "notifications.contoso.com"
```

With optional parameters:
```powershell
.\deploy.ps1 -CustomDomain "mail.yourdomain.com" -ResourceGroup "my-rg" -Location "westus2" -Prefix "myapp"
```

### Linux / macOS (Bash)

```bash
az login
chmod +x deploy.sh
./deploy.sh notifications.contoso.com
```

With optional parameters:
```bash
./deploy.sh mail.yourdomain.com my-resource-group eastus myapp
```

### What the script creates:

| Resource | Purpose |
|----------|---------|
| Resource Group | Container for all resources |
| Communication Services | ACS resource (email sending endpoint) |
| Email Communication Services | Email provisioning + domain management |
| Custom Domain | Your domain registered in ACS Email |
| Sender Address | MailFrom address (e.g., `noreply@yourdomain.com`) |
| App Service Plan (B1) | Hosts both web apps |
| Backend Web App | Node.js API with managed identity |
| Frontend Web App | Static HTML/JS/CSS |
| RBAC Role Assignment | Backend identity → Contributor on ACS |

### After deployment:

⚠️ **You must complete DNS verification manually** (one-time setup):

1. Go to Azure Portal → Email Communication Services → Provision domains
2. Click your domain → copy the DNS records shown
3. Add to your DNS registrar:
   - **TXT** record for domain ownership verification
   - **TXT** record for SPF
   - **2x CNAME** records for DKIM
4. Return to Portal → Click **Verify** for each record
5. Once verified, your app can send emails!

---

## Local Development

### 1. Install backend dependencies

```bash
cd backend
npm install
```

### 2. Configure environment variables

```bash
cp .env.example .env
# Edit .env with your ACS endpoint and sender address
```

Example `.env`:
```
ACS_ENDPOINT=https://my-acs-resource.communication.azure.com
ACS_SENDER_ADDRESS=noreply@notifications.contoso.com
PORT=3001
```

### 3. Authenticate locally

DefaultAzureCredential uses your Azure CLI login for local development:

```bash
az login
```

Ensure your Azure account has the **Contributor** role (or at minimum the email send RBAC role) on the ACS resource.

### 4. Run the backend

```bash
cd backend
node server.js
```

Backend starts at `http://localhost:3001`.

### 5. Run the frontend

Open `frontend/index.html` directly in a browser, or use a simple HTTP server:

```bash
cd frontend
npx http-server -p 8080
```

Frontend available at `http://localhost:8080`.

> **Note:** The `API_BASE_URL` in `frontend/app.js` defaults to `http://localhost:3001`. Update it when deploying.

---

## Custom Domain Setup (REQUIRED)

This application requires a **custom verified email domain**. The Azure-managed `*.azurecomm.net` domain is NOT used as the production sender. You may use it only for initial testing if desired.

### Step-by-step custom domain configuration:

#### 1. Create an Email Communication Services resource

1. Azure Portal → Create resource → **Email Communication Services**
2. Select subscription and resource group
3. Choose a name and region → Create

#### 2. Add your custom domain

1. Open the Email Communication Services resource
2. Go to **Provision domains** → **Add domain** → **Custom domain**
3. Enter your domain name (e.g., `notifications.contoso.com`)

#### 3. Verify domain ownership

Add the required **TXT** record to your DNS:

| Type | Name                      | Value                         |
|------|---------------------------|-------------------------------|
| TXT  | `_azure-comm`             | (value shown in Azure Portal) |

Wait for verification to complete (can take a few minutes).

#### 4. Configure SPF

Add an SPF TXT record:

| Type | Name | Value |
|------|------|-------|
| TXT  | @    | `v=spf1 include:spf.protection.outlook.com -all` |

#### 5. Configure DKIM

Add the CNAME records shown in the Azure Portal for DKIM:

| Type  | Name                          | Value                    |
|-------|-------------------------------|--------------------------|
| CNAME | `selector1-azurecomm-prod-net._domainkey` | (shown in portal) |
| CNAME | `selector2-azurecomm-prod-net._domainkey` | (shown in portal) |

#### 6. Configure sender addresses (MailFrom)

1. In the verified domain, go to **MailFrom addresses**
2. Add a sender address, e.g., `noreply@notifications.contoso.com`
3. Optionally set a display name

#### 7. Connect the domain to your ACS resource

1. Open your **Communication Services** resource (not the Email resource)
2. Go to **Email** → **Domains**
3. Click **Connect domain**
4. Select the Email Communication Services resource and the verified custom domain
5. Confirm the connection

After this, your ACS resource can send email from the custom domain.

---

## Azure Deployment

### Deploy the Backend

#### 1. Create an App Service

```bash
az webapp create \
  --resource-group <rg-name> \
  --plan <app-service-plan> \
  --name <backend-app-name> \
  --runtime "NODE:18-lts"
```

#### 2. Enable system-assigned managed identity

```bash
az webapp identity assign \
  --resource-group <rg-name> \
  --name <backend-app-name>
```

Note the `principalId` in the output.

#### 3. Assign RBAC role for ACS email sending

Grant the managed identity permission to send emails through ACS:

```bash
az role assignment create \
  --assignee <principalId> \
  --role "Contributor" \
  --scope /subscriptions/<sub-id>/resourceGroups/<rg-name>/providers/Microsoft.Communication/communicationServices/<acs-resource-name>
```

> **Tip:** For least-privilege, you can use a custom role with only the `Microsoft.Communication/emailServices/send/action` permission once available in your subscription.

#### 4. Configure app settings (environment variables)

```bash
az webapp config appsettings set \
  --resource-group <rg-name> \
  --name <backend-app-name> \
  --settings \
    ACS_ENDPOINT="https://<acs-resource>.communication.azure.com" \
    ACS_SENDER_ADDRESS="noreply@notifications.contoso.com"
```

#### 5. Deploy the code

```bash
cd backend
zip -r backend.zip .
az webapp deploy \
  --resource-group <rg-name> \
  --name <backend-app-name> \
  --src-path backend.zip \
  --type zip
```

#### Optional: User-assigned managed identity

If using a user-assigned identity instead:

```bash
az webapp identity assign \
  --resource-group <rg-name> \
  --name <backend-app-name> \
  --identities <user-assigned-identity-resource-id>

az webapp config appsettings set \
  --resource-group <rg-name> \
  --name <backend-app-name> \
  --settings AZURE_CLIENT_ID="<client-id-of-user-assigned-identity>"
```

### Deploy the Frontend

#### 1. Create a separate App Service for static files

```bash
az webapp create \
  --resource-group <rg-name> \
  --plan <app-service-plan> \
  --name <frontend-app-name> \
  --runtime "NODE:18-lts"
```

#### 2. Update API_BASE_URL

In `frontend/app.js`, change:

```javascript
const API_BASE_URL = "https://<backend-app-name>.azurewebsites.net";
```

#### 3. Deploy

```bash
cd frontend
zip -r frontend.zip .
az webapp deploy \
  --resource-group <rg-name> \
  --name <frontend-app-name> \
  --src-path frontend.zip \
  --type zip
```

> **Alternative:** You can also use Azure Static Web Apps or Azure Blob Storage static website hosting for the frontend.

---

## Environment Variables Reference

| Variable | Required | Description |
|----------|----------|-------------|
| `ACS_ENDPOINT` | Yes | ACS resource endpoint URL |
| `ACS_SENDER_ADDRESS` | Yes | Sender address from custom verified domain |
| `PORT` | No | Server port (default: 3001) |
| `AZURE_CLIENT_ID` | No | Only for user-assigned managed identity |

---

## Testing After Deployment

1. Open the frontend URL in a browser
2. Enter a recipient email, subject, and message
3. Click "Send Email"
4. Check the recipient inbox (also check spam/junk)

Verify backend health:
```bash
curl https://<backend-app-name>.azurewebsites.net/api/health
```

---

## CORS Configuration

For production, restrict CORS in `backend/server.js`:

```javascript
app.use(cors({
    origin: "https://<frontend-app-name>.azurewebsites.net"
}));
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `401 Unauthorized` from ACS | Managed identity not assigned or RBAC role not granted. Verify the identity has at least Contributor on the ACS resource. |
| `403 Forbidden` | The sender address domain is not verified or not connected to the ACS resource. |
| `InvalidSenderAddress` | The MailFrom address doesn't exist on the verified domain. Add it in the Email resource. |
| Emails going to spam | Ensure SPF, DKIM, and optionally DMARC are correctly configured for the custom domain. |
| `CORS error` in browser | Backend CORS not configured, or API_BASE_URL mismatch in frontend. |
| `DefaultAzureCredential` fails locally | Run `az login` to authenticate your local session. |
| `Network error` in frontend | Backend not running or API_BASE_URL is wrong. Check the browser console. |
| `AZURE_CLIENT_ID` error | Only set this if using user-assigned identity. Remove it for system-assigned. |

---

## Security Notes

- **No connection strings** — authentication uses DefaultAzureCredential exclusively
- **No secrets in frontend** — the frontend only knows the backend URL
- **HTML escaping** — all user input is escaped before embedding in email HTML
- **Server-side validation** — all inputs validated on the backend
- **Safe error messages** — internal errors are not exposed to the client

---

## About the Azure-Managed Domain

Azure provides a free `*.azurecomm.net` domain for testing. You can temporarily use it by setting:

```
ACS_SENDER_ADDRESS=DoNotReply@<acs-resource-id>.azurecomm.net
```

**However, this is NOT recommended for production** because:
- You cannot customize the sender address
- Deliverability is lower (shared domain reputation)
- It cannot pass custom DMARC policies

Always use a custom verified domain for real applications.
