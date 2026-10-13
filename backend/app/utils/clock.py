from datetime import UTC, datetime


def utcnow():
    """Current UTC time as a naive datetime (how MySQL DATETIME columns store it)."""
    return datetime.now(UTC).replace(tzinfo=None)
