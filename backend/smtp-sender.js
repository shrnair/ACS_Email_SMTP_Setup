// ============================================================
// SMTP Email Sender — Alternative to ACS SDK
// Uses ACS SMTP relay with Entra ID (Azure AD) authentication.
//
// IMPORTANT: Unlike the SDK approach, SMTP requires:
//   1. An Entra ID App Registration
//   2. A client secret
//   3. The app granted the ACS email send role
// ============================================================

const nodemailer = require("nodemailer");

// ---- Configuration from environment variables ----
const SMTP_HOST = "smtp.azurecomm.net";
const SMTP_PORT = 587;

// Username format: <ACS-Resource-Name>.<Entra-App-ID>.<Entra-Tenant-ID>
const SMTP_USERNAME = process.env.ACS_SMTP_USERNAME;
// Password: Entra App Client Secret
const SMTP_PASSWORD = process.env.ACS_SMTP_PASSWORD;
// Sender: must match a verified MailFrom address on your custom domain
const SENDER_ADDRESS = process.env.ACS_SENDER_ADDRESS;

/**
 * Send an email via ACS SMTP relay using Nodemailer.
 *
 * @param {string} to - Recipient email address
 * @param {string} subject - Email subject
 * @param {string} textBody - Plain text body
 * @param {string} htmlBody - HTML body
 * @returns {Promise<object>} - Nodemailer send result
 */
async function sendEmailViaSMTP(to, subject, textBody, htmlBody) {
    // Create transporter with ACS SMTP settings
    const transporter = nodemailer.createTransport({
        host: SMTP_HOST,
        port: SMTP_PORT,
        secure: false, // STARTTLS on port 587
        auth: {
            user: SMTP_USERNAME,
            pass: SMTP_PASSWORD,
        },
        tls: {
            ciphers: "TLSv1.2",
        },
    });

    // Send the email
    const result = await transporter.sendMail({
        from: SENDER_ADDRESS,
        to: to,
        subject: subject,
        text: textBody,
        html: htmlBody,
    });

    return result;
}

module.exports = { sendEmailViaSMTP };
