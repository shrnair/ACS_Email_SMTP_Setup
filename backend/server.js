// ============================================================
// ACS Email Backend - Express API
// Sends emails via Azure Communication Services using
// DefaultAzureCredential (managed identity / local dev login).
// ============================================================

const express = require("express");
const cors = require("cors");
const { EmailClient } = require("@azure/communication-email");
const { DefaultAzureCredential } = require("@azure/identity");

const app = express();
const PORT = process.env.PORT || 3001;

// ---- Environment variables ----
const ACS_ENDPOINT = process.env.ACS_ENDPOINT;
const ACS_SENDER_ADDRESS = process.env.ACS_SENDER_ADDRESS;

if (!ACS_ENDPOINT || !ACS_SENDER_ADDRESS) {
    console.error("ERROR: ACS_ENDPOINT and ACS_SENDER_ADDRESS must be set.");
    process.exit(1);
}

// ---- Middleware ----
// CORS: allow all origins in development; restrict in production
app.use(cors());
app.use(express.json());

// ---- Create ACS Email client with managed identity ----
const credential = new DefaultAzureCredential();
const emailClient = new EmailClient(ACS_ENDPOINT, credential);

// ---- Routes ----

/**
 * POST /api/send-email
 * Body: { email, subject, message }
 */
app.post("/api/send-email", async (req, res) => {
    try {
        const { email, subject, message } = req.body;

        // Validate required fields
        if (!email || !subject || !message) {
            return res.status(400).json({
                success: false,
                error: "Missing required fields: email, subject, and message are all required.",
            });
        }

        // Validate email format
        if (!isValidEmail(email)) {
            return res.status(400).json({
                success: false,
                error: "Invalid email address format.",
            });
        }

        // Build the email message
        const emailMessage = {
            senderAddress: ACS_SENDER_ADDRESS,
            content: {
                subject: subject,
                plainText: message,
                html: buildHtmlBody(subject, message),
            },
            recipients: {
                to: [{ address: email }],
            },
        };

        // Send email via ACS (long-running operation)
        const poller = await emailClient.beginSend(emailMessage);
        const result = await poller.pollUntilDone();

        if (result.status === "Succeeded") {
            return res.status(200).json({
                success: true,
                messageId: result.id,
            });
        } else {
            console.error("Email send failed with status:", result.status, result.error);
            return res.status(500).json({
                success: false,
                error: "Email delivery failed. Please try again later.",
            });
        }
    } catch (err) {
        console.error("Error sending email:", err.message);
        // Return a safe error message (do not expose internal details)
        return res.status(500).json({
            success: false,
            error: "An internal error occurred while sending the email.",
        });
    }
});

// Health check endpoint
app.get("/api/health", (req, res) => {
    res.json({ status: "ok", timestamp: new Date().toISOString() });
});

// ---- SMTP Route (alternative to SDK) ----
// Uses SMTP relay instead of ACS SDK. Requires Entra ID app registration.
// Only active if ACS_SMTP_USERNAME is configured.
if (process.env.ACS_SMTP_USERNAME && process.env.ACS_SMTP_PASSWORD) {
    const { sendEmailViaSMTP } = require("./smtp-sender");

    app.post("/api/send-email-smtp", async (req, res) => {
        try {
            const { email, subject, message } = req.body;

            if (!email || !subject || !message) {
                return res.status(400).json({
                    success: false,
                    error: "Missing required fields: email, subject, and message are all required.",
                });
            }

            if (!isValidEmail(email)) {
                return res.status(400).json({
                    success: false,
                    error: "Invalid email address format.",
                });
            }

            const result = await sendEmailViaSMTP(
                email,
                subject,
                message,
                buildHtmlBody(subject, message)
            );

            return res.status(200).json({
                success: true,
                messageId: result.messageId,
            });
        } catch (err) {
            console.error("SMTP send error:", err.message);
            return res.status(500).json({
                success: false,
                error: "An internal error occurred while sending the email via SMTP.",
            });
        }
    });

    console.log("SMTP route enabled: POST /api/send-email-smtp");
}

// ---- Helper functions ----

/**
 * Validates email format using a simple regex.
 */
function isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

/**
 * Escapes HTML special characters to prevent injection.
 */
function escapeHtml(text) {
    const map = {
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#039;",
    };
    return text.replace(/[&<>"']/g, (char) => map[char]);
}

/**
 * Builds a simple, styled HTML email body from the subject and message.
 */
function buildHtmlBody(subject, message) {
    const safeSubject = escapeHtml(subject);
    const safeMessage = escapeHtml(message).replace(/\n/g, "<br>");

    return `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 0; padding: 20px; background-color: #f4f4f5;">
    <div style="max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.08);">
        <div style="background: linear-gradient(135deg, #667eea, #764ba2); padding: 24px 32px;">
            <h1 style="color: #ffffff; margin: 0; font-size: 20px;">${safeSubject}</h1>
        </div>
        <div style="padding: 32px;">
            <p style="color: #374151; line-height: 1.6; font-size: 16px;">${safeMessage}</p>
        </div>
        <div style="padding: 16px 32px; background: #f9fafb; border-top: 1px solid #e5e7eb;">
            <p style="color: #9ca3af; font-size: 12px; margin: 0;">Sent via Azure Communication Services Email Demo</p>
        </div>
    </div>
</body>
</html>`;
}

// ---- Start server ----
app.listen(PORT, () => {
    console.log(`Backend running on http://localhost:${PORT}`);
    console.log(`ACS Endpoint: ${ACS_ENDPOINT}`);
    console.log(`Sender Address: ${ACS_SENDER_ADDRESS}`);
});
