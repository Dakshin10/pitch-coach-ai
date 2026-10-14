"""
FastAPI router for Resume & Job Description Interview Question Generation.
"""
import logging
from typing import Optional
from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from limiter import limiter
from auth.dependencies import get_current_user_optional
from models import User
from resume.sanitizer import extract_resume_text, is_scanned_pdf, sanitize_pii
from resume.pipeline import ResumeInterviewQuestions, generate_resume_questions

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/resume", tags=["resume"])

MAX_RESUME_BYTES = 10 * 1024 * 1024  # 10 MB


@router.post(
    "/generate-questions",
    response_model=ResumeInterviewQuestions,
    summary="Generate tailored technical and behavioral interview questions from a resume PDF or JD text",
)
@limiter.limit("20/minute")
async def generate_questions_endpoint(
    request: Request,
    resume_file: Optional[UploadFile] = File(None),
    jd_text: Optional[str] = Form(None),
    resume_text: Optional[str] = Form(None),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    """
    Accepts a resume PDF upload or pasted resume/JD text.
    Extracts text using PyMuPDF sorted blocks, redacts all candidate PII (email, phone, address),
    and synthesizes 5 behavioral + 5 technical questions via Groq LLM.
    """
    extracted_text = ""

    if resume_file is not None and resume_file.filename:
        filename = resume_file.filename.lower()
        if not filename.endswith(".pdf"):
            raise HTTPException(
                status_code=400,
                detail="Only PDF resume files are supported. Please upload a .pdf file.",
            )

        pdf_bytes = await resume_file.read(MAX_RESUME_BYTES + 1)
        if len(pdf_bytes) > MAX_RESUME_BYTES:
            raise HTTPException(
                status_code=400,
                detail="Resume file exceeds the maximum allowed limit of 10MB.",
            )

        if not pdf_bytes or not pdf_bytes.startswith(b"%PDF"):
            raise HTTPException(
                status_code=400,
                detail="Invalid PDF file format. The uploaded file is corrupt or not a valid PDF.",
            )

        try:
            extracted_text = extract_resume_text(pdf_bytes)
        except Exception as exc:
            logger.warning("[resume_router] PDF extraction error: %s", exc)
            raise HTTPException(
                status_code=400,
                detail=f"Failed to extract text from PDF: {exc}",
            )

        if is_scanned_pdf(extracted_text):
            raise HTTPException(
                status_code=400,
                detail="Scanned PDF not supported yet. Please upload a PDF with selectable text.",
            )

    elif resume_text and resume_text.strip():
        extracted_text = resume_text.strip()

    if not extracted_text.strip() and not (jd_text and jd_text.strip()):
        raise HTTPException(
            status_code=400,
            detail="Please upload a resume PDF or provide resume / job description text.",
        )

    # Sanitize candidate personal contact information before processing
    sanitized_resume = sanitize_pii(extracted_text) if extracted_text else ""
    sanitized_jd = sanitize_pii(jd_text.strip()) if jd_text and jd_text.strip() else None

    # Synthesize interview questions
    result = generate_resume_questions(
        sanitized_resume_text=sanitized_resume,
        jd_text=sanitized_jd,
    )

    return result
