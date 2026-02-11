"""
Helper class to make admin dependency easier to use
"""
from typing import NamedTuple

class AdminContext(NamedTuple):
    """Admin authentication context with establishment"""
    user: any
    establishment_id: str | None
