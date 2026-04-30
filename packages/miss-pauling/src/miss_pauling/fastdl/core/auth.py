from typing import Optional, List
from fastapi import HTTPException, Request, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from miss_pauling.shared.database import get_db
from miss_pauling.shared.repositories import UserRepository


class AuthenticatedUser(BaseModel):
    """User information from authentication"""
    user_id: int
    name: Optional[str] = None
    discord_id: Optional[str] = None
    steam_id64: Optional[str] = None
    roles: List[str] = []
    is_authenticated: bool = True


def validate_session(session_token: str, db: Session) -> Optional[AuthenticatedUser]:
    """
    Validate a session token directly via the shared database.

    Returns user info if valid, None if invalid/expired.
    """
    try:
        session = UserRepository.get_session(db, session_token)
        if not session:
            return None

        user = UserRepository.get_user_by_id(db, session.user_id)
        if not user:
            return None

        # Get user roles
        user_roles = UserRepository.get_user_roles(db, user.id)
        role_names = [role.name.value for role in user_roles]

        return AuthenticatedUser(
            user_id=user.id,
            name=user.name,
            discord_id=user.discord_id,
            steam_id64=user.steam_id64,
            roles=role_names,
            is_authenticated=True,
        )
    except Exception as e:
        print(f"Error validating session: {e}")
        return None


async def get_current_user(
    request: Request,
    db: Session = Depends(get_db),
) -> Optional[AuthenticatedUser]:
    """
    FastAPI dependency to get current authenticated user.
    Returns None if not authenticated (doesn't raise exception).
    """
    session_token = request.cookies.get("session_token")
    if not session_token:
        return None

    return validate_session(session_token, db)


async def require_auth(
    request: Request,
    db: Session = Depends(get_db),
) -> AuthenticatedUser:
    """
    FastAPI dependency that requires authentication.
    Raises 401 HTTPException if not authenticated.
    """
    session_token = request.cookies.get("session_token")
    if not session_token:
        raise HTTPException(status_code=401, detail="Authentication required")

    user = validate_session(session_token, db)
    if not user:
        raise HTTPException(status_code=401, detail="Authentication required")
    return user


def get_role_hierarchy(role_name: str) -> int:
    """Get hierarchy level for a role (lower number = higher privilege)"""
    hierarchy = {
        "superadmin": 0,
        "administrator": 1,
        "moderator": 2,
        "helper": 3,
        "captain": 4,
        "user": 5
    }
    return hierarchy.get(role_name.lower(), 999)


def user_has_role_level(user: AuthenticatedUser, required_level: int) -> bool:
    """Check if user has a role at the required level or higher"""
    if not user.roles:
        return False

    user_highest_level = min(get_role_hierarchy(role) for role in user.roles)
    return user_highest_level <= required_level


async def require_helper_or_above(
    request: Request,
    db: Session = Depends(get_db),
) -> AuthenticatedUser:
    """
    FastAPI dependency that requires helper role or above.
    Raises 403 HTTPException if insufficient privileges.
    """
    user = await require_auth(request, db)

    if not user_has_role_level(user, 3):  # helper level = 3
        raise HTTPException(
            status_code=403,
            detail="Helper privileges or above required for this action"
        )

    return user
