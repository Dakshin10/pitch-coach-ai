"""Auth routes: signup, login, guest, refresh, upgrade-guest."""
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from firebase_admin import auth as fb_auth
from google.cloud import firestore as fs

from auth.dependencies import get_current_user
from auth.utils import create_access_token, create_refresh_token, decode_token, hash_password, verify_password
from config import get_settings
from firestore import get_db
from limiter import limiter
from models import User, USERS_COL
from schemas import AuthResponse, FirebaseLoginRequest, LoginRequest, RefreshRequest, SignupRequest, UpgradeGuestRequest, UserResponse

router = APIRouter(prefix="/auth", tags=["auth"])
settings = get_settings()

USER_EMAILS_COL = "user_emails"


def _build_auth_response(user: User) -> AuthResponse:
    return AuthResponse(
        access_token=create_access_token({"sub": user.id}),
        refresh_token=create_refresh_token({"sub": user.id}),
        user=UserResponse(
            id=user.id,
            email=user.email,
            full_name=user.full_name,
            role_occupation=user.role_occupation,
            primary_objective=user.primary_objective,
            target_industry=user.target_industry,
            experience_level=user.experience_level,
            feedback_style=user.feedback_style,
            is_guest=user.is_guest,
            dark_mode=user.dark_mode,
        ),
    )


def _register_user_atomic(db: fs.Client, user: User, normalized_email: str):
    """Atomically registers user and locks unique email in user_emails collection."""
    email_ref = db.collection(USER_EMAILS_COL).document(normalized_email)
    user_ref = db.collection(USERS_COL).document(user.id)

    # Check existing users collection for backward compatibility
    existing = db.collection(USERS_COL).where("email", "==", normalized_email).limit(1).get()
    if len(list(existing)) > 0:
        raise HTTPException(status_code=400, detail="Email already registered")

    if hasattr(db, "transaction"):
        transaction = db.transaction()

        @fs.transactional
        def _txn(t):
            email_doc = email_ref.get(transaction=t)
            if email_doc.exists:
                raise HTTPException(status_code=400, detail="Email already registered")
            t.set(email_ref, {"user_id": user.id, "created_at": datetime.now(timezone.utc)})
            t.set(user_ref, user.to_dict())

        _txn(transaction)
    else:
        email_doc = email_ref.get()
        if email_doc.exists:
            raise HTTPException(status_code=400, detail="Email already registered")
        email_ref.set({"user_id": user.id, "created_at": datetime.now(timezone.utc)})
        user_ref.set(user.to_dict())


def _upgrade_user_atomic(db: fs.Client, user_id: str, normalized_email: str, update_dict: dict):
    """Atomically reserves email and updates guest user document."""
    email_ref = db.collection(USER_EMAILS_COL).document(normalized_email)
    user_ref = db.collection(USERS_COL).document(user_id)

    existing = db.collection(USERS_COL).where("email", "==", normalized_email).limit(1).get()
    if len(list(existing)) > 0:
        raise HTTPException(status_code=400, detail="Email already registered")

    if hasattr(db, "transaction"):
        transaction = db.transaction()

        @fs.transactional
        def _txn(t):
            email_doc = email_ref.get(transaction=t)
            if email_doc.exists:
                raise HTTPException(status_code=400, detail="Email already registered")
            t.set(email_ref, {"user_id": user_id, "created_at": datetime.now(timezone.utc)})
            t.update(user_ref, update_dict)

        _txn(transaction)
    else:
        email_doc = email_ref.get()
        if email_doc.exists:
            raise HTTPException(status_code=400, detail="Email already registered")
        email_ref.set({"user_id": user_id, "created_at": datetime.now(timezone.utc)})
        user_ref.update(update_dict)


@router.post("/signup", response_model=AuthResponse)
@limiter.limit("5/minute")
def signup(request: Request, req: SignupRequest, db: fs.Client = Depends(get_db)):
    email_normalized = req.email.strip().lower()
    user = User(
        id=str(uuid.uuid4()),
        email=email_normalized,
        password_hash=hash_password(req.password),
        full_name=req.full_name.strip(),
        is_guest=False,
    )
    _register_user_atomic(db, user, email_normalized)
    return _build_auth_response(user)


@router.post("/login", response_model=AuthResponse)
@limiter.limit("5/minute")
def login(request: Request, req: LoginRequest, db: fs.Client = Depends(get_db)):
    email_normalized = req.email.strip().lower()
    docs = db.collection(USERS_COL).where("email", "==", email_normalized).limit(1).get()
    doc_list = list(docs)
    if not doc_list:
        raise HTTPException(status_code=401, detail="Invalid email or password")
    user = User.from_dict(doc_list[0].to_dict())
    if not user.password_hash or not verify_password(req.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    return _build_auth_response(user)


@router.post("/firebase", response_model=AuthResponse)
def firebase_login(req: FirebaseLoginRequest, db: fs.Client = Depends(get_db)):
    """Exchange a Firebase ID token (from the Flutter app) for backend JWTs.

    The Firebase uid is used as the user document id, so the same person
    always maps to the same Firestore user. The user doc is created on first use.
    """
    try:
        decoded = fb_auth.verify_id_token(req.id_token)
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid Firebase token")

    uid: str = decoded["uid"]
    doc = db.collection(USERS_COL).document(uid).get()
    if doc.exists:
        user = User.from_dict(doc.to_dict())
    else:
        email = decoded.get("email")
        if email:
            email = email.strip().lower()
        user = User(
            id=uid,
            email=email,
            full_name=decoded.get("name") or "User",
            is_guest=False,
        )
        db.collection(USERS_COL).document(uid).set(user.to_dict())
        if email:
            db.collection(USER_EMAILS_COL).document(email).set({
                "user_id": uid,
                "created_at": datetime.now(timezone.utc),
            })
    return _build_auth_response(user)


@router.post("/guest", response_model=AuthResponse)
@limiter.limit("10/hour")
def guest_login(request: Request, db: fs.Client = Depends(get_db)):
    """Creates an anonymous account. History is preserved if the user later upgrades."""
    user = User(
        id=str(uuid.uuid4()),
        is_guest=True,
        full_name="Guest User",
        expires_at=datetime.now(timezone.utc) + timedelta(days=settings.GUEST_EXPIRE_DAYS),
    )
    db.collection(USERS_COL).document(user.id).set(user.to_dict())
    return _build_auth_response(user)


@router.post("/refresh")
@limiter.limit("10/minute")
def refresh_token(request: Request, req: RefreshRequest, db: fs.Client = Depends(get_db)):
    payload = decode_token(req.refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    user_id: str = payload["sub"]
    doc = db.collection(USERS_COL).document(user_id).get()
    if not doc.exists:
        raise HTTPException(status_code=401, detail="User not found")
    return {"access_token": create_access_token({"sub": user_id}), "token_type": "bearer"}


@router.post("/upgrade-guest", response_model=AuthResponse)
def upgrade_guest(
    req: UpgradeGuestRequest,
    current_user: User = Depends(get_current_user),
    db: fs.Client = Depends(get_db),
):
    """Convert a guest account into a full account — keeps all session history."""
    if not current_user.is_guest:
        raise HTTPException(status_code=400, detail="Not a guest account")

    email_normalized = req.email.strip().lower()
    update_dict = {
        "email": email_normalized,
        "password_hash": hash_password(req.password),
        "full_name": req.full_name.strip(),
        "is_guest": False,
        "expires_at": None,
    }
    _upgrade_user_atomic(db, current_user.id, email_normalized, update_dict)

    # Refresh local object
    current_user.email = email_normalized
    current_user.full_name = req.full_name.strip()
    current_user.is_guest = False
    current_user.expires_at = None
    return _build_auth_response(current_user)
