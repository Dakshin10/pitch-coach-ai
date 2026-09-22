"""Auth routes: signup, login, guest, refresh, upgrade-guest."""
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from auth.dependencies import get_current_user
from auth.utils import create_access_token, create_refresh_token, decode_token, hash_password, verify_password
from config import get_settings
from database import get_db
from models import User
from schemas import AuthResponse, LoginRequest, RefreshRequest, SignupRequest, UpgradeGuestRequest, UserResponse

router = APIRouter(prefix="/auth", tags=["auth"])
settings = get_settings()


def _build_auth_response(user: User) -> AuthResponse:
    return AuthResponse(
        access_token=create_access_token({"sub": user.id}),
        refresh_token=create_refresh_token({"sub": user.id}),
        user=UserResponse.model_validate(user),
    )


@router.post("/signup", response_model=AuthResponse)
def signup(req: SignupRequest, db: Session = Depends(get_db)):
    if db.query(User).filter(User.email == req.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")
    user = User(
        id=str(uuid.uuid4()),
        email=req.email,
        password_hash=hash_password(req.password),
        full_name=req.full_name,
        is_guest=False,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return _build_auth_response(user)


@router.post("/login", response_model=AuthResponse)
def login(req: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == req.email).first()
    if not user or not user.password_hash or not verify_password(req.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    return _build_auth_response(user)


@router.post("/guest", response_model=AuthResponse)
def guest_login(db: Session = Depends(get_db)):
    """Creates an anonymous account. History is preserved if the user later upgrades."""
    user = User(
        id=str(uuid.uuid4()),
        is_guest=True,
        full_name="Guest User",
        expires_at=datetime.now(timezone.utc) + timedelta(days=settings.GUEST_EXPIRE_DAYS),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return _build_auth_response(user)


@router.post("/refresh")
def refresh_token(req: RefreshRequest, db: Session = Depends(get_db)):
    payload = decode_token(req.refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    user = db.query(User).filter(User.id == payload["sub"]).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return {"access_token": create_access_token({"sub": user.id}), "token_type": "bearer"}


@router.post("/upgrade-guest", response_model=AuthResponse)
def upgrade_guest(
    req: UpgradeGuestRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Convert a guest account into a full account — keeps all session history."""
    if not current_user.is_guest:
        raise HTTPException(status_code=400, detail="Not a guest account")
    if db.query(User).filter(User.email == req.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")
    current_user.email = req.email
    current_user.password_hash = hash_password(req.password)
    current_user.full_name = req.full_name
    current_user.is_guest = False
    current_user.expires_at = None
    db.commit()
    db.refresh(current_user)
    return _build_auth_response(current_user)
