"""GET /me and PATCH /me — user profile endpoints."""
from fastapi import APIRouter, Depends
from google.cloud import firestore as fs

from auth.dependencies import get_current_user
from firestore import get_db
from models import User, USERS_COL
from schemas import UpdateProfileRequest, UserResponse

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserResponse)
def get_me(current_user: User = Depends(get_current_user)):
    return UserResponse(
        id=current_user.id,
        email=current_user.email,
        full_name=current_user.full_name,
        role_occupation=current_user.role_occupation,
        primary_objective=current_user.primary_objective,
        target_industry=current_user.target_industry,
        experience_level=current_user.experience_level,
        feedback_style=current_user.feedback_style,
        is_guest=current_user.is_guest,
        dark_mode=current_user.dark_mode,
    )


@router.patch("/me", response_model=UserResponse)
def update_me(
    req: UpdateProfileRequest,
    current_user: User = Depends(get_current_user),
    db: fs.Client = Depends(get_db),
):
    updates = req.model_dump(exclude_none=True)
    if updates:
        db.collection(USERS_COL).document(current_user.id).update(updates)
        for field, value in updates.items():
            setattr(current_user, field, value)
    return UserResponse(
        id=current_user.id,
        email=current_user.email,
        full_name=current_user.full_name,
        role_occupation=current_user.role_occupation,
        primary_objective=current_user.primary_objective,
        target_industry=current_user.target_industry,
        experience_level=current_user.experience_level,
        feedback_style=current_user.feedback_style,
        is_guest=current_user.is_guest,
        dark_mode=current_user.dark_mode,
    )
