import re

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
# Cambodian numbers: 0XX XXX XXX(X) or +855 XX XXX XXX(X), after removing spaces/dashes
PHONE_RE = re.compile(r"^(\+855|0)\d{8,9}$")


def require_fields(data, fields):
    """Return {field: message} for every required field that is missing or blank."""
    return {
        f: f"{f} is required"
        for f in fields
        if data.get(f) is None or str(data.get(f)).strip() == ""
    }


def is_valid_email(email):
    return bool(EMAIL_RE.match(email or ""))


def normalize_phone(phone):
    """Strip spaces, dashes, dots and brackets; return None for an empty value."""
    cleaned = re.sub(r"[\s\-().]", "", phone or "")
    return cleaned or None


def is_valid_phone(phone):
    return bool(PHONE_RE.match(phone or ""))
