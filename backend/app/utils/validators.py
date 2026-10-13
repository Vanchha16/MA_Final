import re

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def require_fields(data, fields):
    """Return {field: message} for every required field that is missing or blank."""
    return {
        f: f"{f} is required"
        for f in fields
        if data.get(f) is None or str(data.get(f)).strip() == ""
    }


def is_valid_email(email):
    return bool(EMAIL_RE.match(email or ""))
