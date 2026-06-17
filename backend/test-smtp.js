// ============================================================
// SMTP Test Script
// Run this to verify your ACS SMTP configuration works.
//
// Usage:
//   set ACS_SMTP_USERNAME=<resource>.<appId>.<tenantId>
//   set ACS_SMTP_PASSWORD=<client-secret>
//   set ACS_SENDER_ADDRESS=noreply@notifications.contoso.com
//   node test-smtp.js recipient@example.com
// ============================================================

const { sendEmailViaSMTP } = require("./smtp-sender");

async function main() {
    const recipient = process.argv[2];

    if (!recipient) {
        console.error("Usage: node test-smtp.js <recipient-email>");
        console.error("Example: node test-smtp.js user@example.com");
        process.exit(1);
    }

    // Check required env vars
    const required = ["ACS_SMTP_USERNAME", "ACS_SMTP_PASSWORD", "ACS_SENDER_ADDRESS"];
    const missing = required.filter((v) => !process.env[v]);
    if (missing.length > 0) {
        console.error(`Missing environment variables: ${missing.join(", ")}`);
        console.error("");
        console.error("Required format:");
        console.error("  ACS_SMTP_USERNAME = <ACS-Resource-Name>.<Entra-App-ID>.<Entra-Tenant-ID>");
        console.error("  ACS_SMTP_PASSWORD = <Entra-App-Client-Secret>");
        console.error("  ACS_SENDER_ADDRESS = noreply@your-verified-domain.com");
        process.exit(1);
    }

    console.log("Sending test email via SMTP...");
    console.log(`  From: ${process.env.ACS_SENDER_ADDRESS}`);
    console.log(`  To:   ${recipient}`);
    console.log(`  Host: smtp.azurecomm.net:587`);
    console.log("");

    try {
        const result = await sendEmailViaSMTP(
            recipient,
            "ACS SMTP Test — " + new Date().toLocaleString(),
            "This is a test email sent via Azure Communication Services SMTP relay.",
            `<html><body>
                <h2>✅ SMTP Test Successful</h2>
                <p>This email was sent via <strong>Azure Communication Services SMTP relay</strong>.</p>
                <p>Timestamp: ${new Date().toISOString()}</p>
            </body></html>`
        );

        console.log("✅ Email sent successfully!");
        console.log(`   Message ID: ${result.messageId}`);
        console.log(`   Response: ${result.response}`);
    } catch (err) {
        console.error("❌ Failed to send email:");
        console.error(`   Error: ${err.message}`);
        if (err.responseCode === 535) {
            console.error("   → Authentication failed. Check your username/password format.");
        }
        process.exit(1);
    }
}

main();
