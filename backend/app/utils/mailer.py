import smtplib
from email.message import EmailMessage

from flask import current_app


def send_email(to, subject, body):
    """Send a plain-text email, or print it to the server log when MAIL_MODE=console."""
    cfg = current_app.config
    if cfg["MAIL_MODE"] != "smtp":
        current_app.logger.warning("[DEV EMAIL] To: %s | %s\n%s", to, subject, body)
        print(f"\n===== DEV EMAIL to {to} =====\n{subject}\n\n{body}\n=============================\n", flush=True)
        return

    msg = EmailMessage()
    msg["From"] = cfg["MAIL_FROM"]
    msg["To"] = to
    msg["Subject"] = subject
    msg.set_content(body)
    with smtplib.SMTP(cfg["MAIL_SERVER"], cfg["MAIL_PORT"], timeout=15) as smtp:
        smtp.starttls()
        smtp.login(cfg["MAIL_USERNAME"], cfg["MAIL_PASSWORD"])
        smtp.send_message(msg)
