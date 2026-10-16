import math
import re

from flask import request

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
# Cambodian numbers: 0XX XXX XXX(X) or +855 XX XXX XXX(X), after removing spaces/dashes
PHONE_RE = re.compile(r"^(\+855|0)\d{8,9}$")
# A name needs at least one letter (any language, e.g. Khmer), not just dots or digits
HAS_LETTER_RE = re.compile(r"[^\W\d_]")

# Longest values the database columns hold (MySQL here cuts longer text silently,
# so the API refuses it instead)
NAME_MAX = 100
EMAIL_MAX = 150
PASSWORD_MIN, PASSWORD_MAX = 6, 72  # bcrypt only uses the first 72 bytes
MONEY_MAX = 1_000_000  # dollars; the price columns hold up to 99,999,999.99
STOCK_MAX = 100_000


def json_body():
    """The request's JSON object, or {} when the body is missing, not JSON or not an object."""
    data = request.get_json(silent=True)
    return data if isinstance(data, dict) else {}


def require_fields(data, fields):
    """Return {field: message} for every required field that is missing or blank."""
    return {
        f: f"{f} is required"
        for f in fields
        if data.get(f) is None or str(data.get(f)).strip() == ""
    }


def is_valid_email(email):
    return isinstance(email, str) and bool(EMAIL_RE.match(email))


def normalize_phone(phone):
    """Strip spaces, dashes, dots and brackets; return None for an empty value."""
    if not isinstance(phone, str):
        return None
    cleaned = re.sub(r"[\s\-().]", "", phone)
    return cleaned or None


def is_valid_phone(phone):
    return isinstance(phone, str) and bool(PHONE_RE.match(phone))


class Fields:
    """Reads and checks fields of a JSON body, collecting {field: message} errors.

        f = Fields(json_body())
        name = f.text("full_name", required=True, max_len=100)
        price = f.money("price", required=True)
        if f.errors: return error("Validation failed", 422, f.errors)

    A field that has an error reads as None.
    """

    def __init__(self, data):
        self.data = data if isinstance(data, dict) else {}
        self.errors = {}

    def has(self, name):
        return name in self.data

    def _fail(self, name, message):
        self.errors.setdefault(name, message)
        return None

    def text(self, name, *, required=False, max_len=None, min_len=0, label=None, strip=True, default=None):
        """A string (numbers are refused, so a typo can't crash the server). Blank = None."""
        label = label or name
        value = self.data.get(name)
        if value is None or (isinstance(value, str) and not value.strip()):
            return self._fail(name, f"{label} is required") if required else default
        if not isinstance(value, str):
            return self._fail(name, f"{label} must be text")
        if strip:
            value = value.strip()
        if max_len and len(value) > max_len:
            return self._fail(name, f"Keep {label} under {max_len} characters")
        if len(value) < min_len:
            return self._fail(name, f"{label} is too short")
        return value

    def password(self, name, *, label="Password"):
        value = self.data.get(name)
        if value is None or value == "":
            return self._fail(name, f"{label} is required")
        if not isinstance(value, str):
            return self._fail(name, f"{label} must be text")
        if len(value) < PASSWORD_MIN:
            return self._fail(name, f"{label} must be at least {PASSWORD_MIN} characters")
        if len(value.encode()) > PASSWORD_MAX:
            return self._fail(name, f"Keep {label} under {PASSWORD_MAX} characters")
        return value

    def person_name(self, name, *, required=True, label="Name"):
        value = self.text(name, required=required, max_len=NAME_MAX, label=label)
        if value is not None and (len(value) < 2 or not HAS_LETTER_RE.search(value)):
            return self._fail(name, f"{label} is too short" if len(value) < 2 else f"{label} needs letters")
        return value

    def email(self, name="email", *, required=True):
        value = self.text(name, required=required, max_len=EMAIL_MAX, label="Email")
        if value is not None and not EMAIL_RE.match(value):
            return self._fail(name, "Email is not valid")
        return value.lower() if value else value

    def phone(self, name="phone", *, required=False, label="Phone number"):
        """A Cambodian number, returned without spaces or dashes."""
        value = self.text(name, required=required, max_len=30, label=label)
        if value is None:
            return None
        cleaned = normalize_phone(value)
        if not is_valid_phone(cleaned):
            return self._fail(name, "Enter a Cambodian number, e.g. 012 345 678")
        return cleaned

    def integer(self, name, *, required=False, min_value=None, max_value=None, label=None):
        """A whole number: 3 or "3" (not 2.9, "abc" or true)."""
        label = label or name
        value = self.data.get(name)
        if value is None or value == "":
            return self._fail(name, f"{label} is required") if required else None
        if isinstance(value, bool):
            return self._fail(name, f"{label} must be a whole number")
        if isinstance(value, float) and value.is_integer():
            value = int(value)
        if isinstance(value, str) and re.fullmatch(r"\s*-?\d+\s*", value):
            value = int(value)
        if not isinstance(value, int):
            return self._fail(name, f"{label} must be a whole number")
        if min_value is not None and value < min_value:
            return self._fail(name, f"{label} must be {min_value} or more")
        if max_value is not None and value > max_value:
            return self._fail(name, f"{label} must be {max_value:,} or less")
        return value

    def money(self, name, *, required=False, label=None, max_value=MONEY_MAX):
        """A price in dollars, more than 0, rounded to cents."""
        label = label or name
        value = self.data.get(name)
        if value is None or value == "":
            return self._fail(name, f"{label} is required") if required else None
        if isinstance(value, bool):
            return self._fail(name, f"{label} must be a number")
        try:
            number = float(value)
        except (TypeError, ValueError):
            return self._fail(name, f"{label} must be a number")
        if not math.isfinite(number):
            return self._fail(name, f"{label} must be a number")
        if number <= 0:
            return self._fail(name, f"{label} must be more than 0")
        if number > max_value:
            return self._fail(name, f"{label} must be {max_value:,} or less")
        return round(number, 2)

    def boolean(self, name, *, label=None):
        """true or false only ("false" as text is refused, not read as true)."""
        value = self.data.get(name)
        if not isinstance(value, bool):
            return self._fail(name, f"{label or name} must be true or false")
        return value

    def choice(self, name, choices, *, required=False, default=None, message=None):
        value = self.data.get(name, default)
        if value is None:
            return self._fail(name, message or f"{name} is required") if required else None
        if not isinstance(value, str) or value not in choices:
            return self._fail(name, message or f"Must be one of: {', '.join(choices)}")
        return value
