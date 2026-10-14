"""
PDF text extraction and PII sanitization for resumes.
Uses PyMuPDF sorted block extraction to preserve reading order in multi-column layouts.
Redacts personal identifiers (email, phone, physical address) before LLM prompt injection.
"""
import re
from typing import Tuple
import pymupdf


def extract_resume_text(pdf_bytes: bytes) -> str:
    """
    Extract text from a resume PDF using sorted block extraction.
    pymupdf's sort=True orders blocks by vertical position then horizontal,
    handling standard two-column and one-column layouts accurately.
    """
    if not pdf_bytes or not pdf_bytes.startswith(b"%PDF"):
        raise ValueError("Invalid PDF file: magic bytes missing or empty.")

    doc = pymupdf.open(stream=pdf_bytes, filetype="pdf")
    try:
        pages_text = []
        for page_idx in range(len(doc)):
            page = doc[page_idx]
            # blocks format: (x0, y0, x1, y1, text, block_no, block_type)
            # block_type 0 = text, 1 = image
            blocks = page.get_text("blocks", sort=True)
            page_blocks = []
            for b in blocks:
                if len(b) >= 7 and b[6] == 0:  # text block
                    text = b[4].strip()
                    if text:
                        page_blocks.append(text)
                elif len(b) >= 5 and isinstance(b[4], str) and b[4].strip():
                    page_blocks.append(b[4].strip())
            if page_blocks:
                pages_text.append("\n\n".join(page_blocks))
        return "\n\n--- Page Break ---\n\n".join(pages_text)
    finally:
        doc.close()


def is_scanned_pdf(text: str, min_chars: int = 40) -> bool:
    """Returns True if the PDF has virtually no extractable text (scanned image PDF)."""
    clean = re.sub(r"\s+", "", text or "")
    return len(clean) < min_chars


def sanitize_pii(text: str) -> str:
    """
    Strip candidate emails, phone numbers, and street addresses/locations
    to ensure personal contact details never reach external LLM endpoints.
    """
    if not text:
        return ""

    sanitized = text

    # 1. Emails: standard RFC 5322 approximation
    email_regex = re.compile(
        r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b",
        flags=re.IGNORECASE,
    )
    sanitized = email_regex.sub("[EMAIL REDACTED]", sanitized)

    # 2. Phone numbers:
    # International e.g. +1 (555) 123-4567, +91 9876543210, (555) 000-1111, 555-123-4567, +44 20 7946 0919
    phone_regex = re.compile(
        r"(?:\+?\d{1,3}[\s.-]?)?(?:\(?\d{2,4}\)?[\s.-]?)?\d{3,4}[\s.-]?\d{3,5}\b",
    )
    # We apply phone regex with filter to avoid redacting 4-digit years like 2021-2024
    def _replace_phone(match):
        val = match.group(0).strip()
        digits = re.sub(r"\D", "", val)
        # Avoid year ranges like 2020 - 2024
        if len(digits) >= 7 and not (len(digits) == 8 and (digits.startswith("19") or digits.startswith("20"))):
            return "[PHONE REDACTED]"
        return val

    sanitized = phone_regex.sub(_replace_phone, sanitized)

    # 3. Physical street addresses:
    # E.g. "123 Main St, Apt 4B, Springfield, IL 62701", "42 Baker Street, London NW1 6XE",
    # "Flat 302, Green Glen Layout, Bellandur, Bangalore 560103"
    address_patterns = [
        # Number + Street name + Suffix
        re.compile(
            r"\b\d{1,5}\s+[A-Za-z0-9\s.,]{2,35}\b(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln|Way|Court|Ct|Circle|Cir|Terrace|Ter|Parkway|Pkwy|Colony|Layout|Nagar|Sector|Enclave)\b[A-Za-z0-9\s.,#\-_]*",
            flags=re.IGNORECASE,
        ),
        # Apartment / Suite / Flat
        re.compile(
            r"\b(?:Apt|Apartment|Suite|Unit|Flat|House|Room|Plot|Door)\s*#?\s*[A-Za-z0-9\-]+\b",
            flags=re.IGNORECASE,
        ),
        # US State + Zip
        re.compile(
            r"\b[A-Z]{2}\s+\d{5}(?:-\d{4})?\b",
        ),
        # 6-digit pin code with optional Zip/PIN prefix
        re.compile(
            r"\b(?:PIN|PINCODE|ZIP|POSTAL CODE)?\s*:?\s*\d{6}\b",
            flags=re.IGNORECASE,
        ),
    ]

    for pat in address_patterns:
        sanitized = pat.sub("[ADDRESS REDACTED]", sanitized)

    # Clean up multiple redactions in sequence
    sanitized = re.sub(r"(\[ADDRESS REDACTED\][\s,;]*){2,}", "[ADDRESS REDACTED] ", sanitized)
    sanitized = re.sub(r"(\[PHONE REDACTED\][\s,;]*){2,}", "[PHONE REDACTED] ", sanitized)

    return sanitized
