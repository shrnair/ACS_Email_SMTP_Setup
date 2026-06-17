// ============================================================
// Configuration
// Change API_BASE_URL to match your backend deployment:
//   - Local development: "http://localhost:3001"
//   - Azure deployed:    "https://<your-backend-app>.azurewebsites.net"
// ============================================================
const API_BASE_URL = "http://localhost:3001";

// DOM elements
const form = document.getElementById("emailForm");
const sendBtn = document.getElementById("sendBtn");
const statusDiv = document.getElementById("status");

// Listen for form submission
form.addEventListener("submit", async (e) => {
    e.preventDefault();

    const email = document.getElementById("recipient").value.trim();
    const subject = document.getElementById("subject").value.trim();
    const message = document.getElementById("message").value.trim();

    // Basic client-side validation
    if (!email || !subject || !message) {
        showStatus("Please fill in all fields.", "error");
        return;
    }

    if (!isValidEmail(email)) {
        showStatus("Please enter a valid email address.", "error");
        return;
    }

    // Disable button and show sending status
    sendBtn.disabled = true;
    sendBtn.textContent = "Sending…";
    showStatus("Sending email…", "sending");

    try {
        const response = await fetch(`${API_BASE_URL}/api/send-email`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ email, subject, message }),
        });

        const data = await response.json();

        if (response.ok && data.success) {
            showStatus("✅ Email sent successfully!", "success");
            form.reset();
        } else {
            const errorMsg = data.error || "Failed to send email.";
            showStatus(`❌ ${errorMsg}`, "error");
        }
    } catch (err) {
        showStatus("❌ Network error. Is the backend running?", "error");
    } finally {
        sendBtn.disabled = false;
        sendBtn.textContent = "Send Email";
    }
});

/**
 * Display a status message with the given type (sending, success, error).
 */
function showStatus(message, type) {
    statusDiv.textContent = message;
    statusDiv.className = `status ${type}`;
}

/**
 * Simple email format validation.
 */
function isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}
