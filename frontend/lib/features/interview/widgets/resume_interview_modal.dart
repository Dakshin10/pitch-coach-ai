import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/models/resume_interview.dart';
import '../../../core/repositories/resume_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class ResumeInterviewModal extends StatefulWidget {
  final ResumeRepository? resumeRepository;

  const ResumeInterviewModal({
    super.key,
    this.resumeRepository,
  });

  static Future<ResumeQuestionsResult?> show(
    BuildContext context, {
    ResumeRepository? resumeRepository,
  }) {
    return showModalBottomSheet<ResumeQuestionsResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ResumeInterviewModal(resumeRepository: resumeRepository),
    );
  }

  @override
  State<ResumeInterviewModal> createState() => _ResumeInterviewModalState();
}

class _ResumeInterviewModalState extends State<ResumeInterviewModal> {
  late final ResumeRepository _repo;

  String? _pickedFileName;
  String? _pickedFilePath;
  Uint8List? _pickedFileBytes;
  int? _pickedFileSize;

  final TextEditingController _jdController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repo = widget.resumeRepository ?? ResumeRepository.instance;
  }

  @override
  void dispose() {
    _jdController.dispose();
    super.dispose();
  }

  Future<void> _pickResumePdf() async {
    setState(() => _errorMessage = null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        setState(() {
          _pickedFileName = file.name;
          _pickedFilePath = file.path;
          _pickedFileBytes = file.bytes;
          _pickedFileSize = file.size;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to select file: $e');
    }
  }

  void _clearPickedFile() {
    setState(() {
      _pickedFileName = null;
      _pickedFilePath = null;
      _pickedFileBytes = null;
      _pickedFileSize = null;
    });
  }

  Future<void> _generateQuestions() async {
    final hasPdf = _pickedFileName != null;
    final hasJd = _jdController.text.trim().isNotEmpty;

    if (!hasPdf && !hasJd) {
      setState(() {
        _errorMessage = 'Please choose a resume PDF or paste job description text.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _repo.generateQuestions(
        pdfPath: _pickedFilePath,
        pdfBytes: _pickedFileBytes,
        pdfFileName: _pickedFileName,
        jdText: hasJd ? _jdController.text.trim() : null,
      );

      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _isLoading = false;
          _errorMessage = message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 24,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: AppColors.borderOf(context),
          width: 1.2,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderOf(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    color: AppColors.primaryPurple,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resume & JD Practice',
                        style: AppTextStyles.headingMOf(context).copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tailored questions from your actual projects',
                        style: AppTextStyles.captionOf(context),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.textSecondaryOf(context),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Privacy Guarantee Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFF10B981),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Privacy Guard: Emails, phones, and addresses are automatically redacted before analysis.',
                      style: AppTextStyles.captionOf(context).copyWith(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 1. PDF Upload Section
            Text(
              '1. Upload Resume PDF',
              style: AppTextStyles.labelOf(context).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),

            if (_pickedFileName == null)
              InkWell(
                onTap: _isLoading ? null : _pickResumePdf,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : const Color(0xFFF9F9FC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryPurple.withValues(alpha: 0.35),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.cloud_upload_outlined,
                        size: 32,
                        color: AppColors.primaryPurple,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to select resume PDF',
                        style: AppTextStyles.bodyMOf(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Supports single & multi-column PDF resumes (max 10MB)',
                        style: AppTextStyles.captionOf(context).copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : const Color(0xFFF6F5FB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryPurple.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Color(0xFFEF4444),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pickedFileName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyBoldOf(context).copyWith(
                              fontSize: 13,
                            ),
                          ),
                          if (_pickedFileSize != null)
                            Text(
                              '${(_pickedFileSize! / 1024).toStringAsFixed(1)} KB',
                              style: AppTextStyles.captionOf(context).copyWith(
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: _isLoading ? null : _clearPickedFile,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // 2. Job Description Section
            Text(
              '2. Job Description (Optional)',
              style: AppTextStyles.labelOf(context).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _jdController,
              enabled: !_isLoading,
              maxLines: 3,
              style: AppTextStyles.bodyMOf(context).copyWith(
                color: AppColors.textPrimaryOf(context),
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'Paste role requirements or company details here...',
                hintStyle: AppTextStyles.captionOf(context).copyWith(fontSize: 12),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : const Color(0xFFF9F9FC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.borderOf(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.borderOf(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primaryPurple, width: 1.5),
                ),
              ),
            ),

            // Error Banner (Empty or Error state)
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action Button / Loading State
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isLoading ? null : _generateQuestions,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 20),
                label: Text(
                  _isLoading
                      ? 'Analyzing Resume & Generating...'
                      : 'Generate 10 Interview Questions',
                  style: AppTextStyles.bodyM.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
