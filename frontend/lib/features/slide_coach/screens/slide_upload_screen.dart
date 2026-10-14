import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/slide_coach_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/theme_toggle_button.dart';

class SlideUploadScreen extends StatefulWidget {
  const SlideUploadScreen({super.key});

  @override
  State<SlideUploadScreen> createState() => _SlideUploadScreenState();
}

class _SlideUploadScreenState extends State<SlideUploadScreen> {
  String? _pickedFilePath;
  String? _pickedFileName;
  int? _pickedFileSize;

  String _selectedAudience = 'investors';
  int _timeLimitMinutes = 3;
  final TextEditingController _goalController = TextEditingController(
    text: 'Win hackathon grand finale & convince judges',
  );

  final List<Map<String, String>> _audiences = [
    {'id': 'investors', 'label': 'Investors / VCs'},
    {'id': 'hackathon_judges', 'label': 'Hackathon Judges'},
    {'id': 'customers', 'label': 'Potential Clients'},
    {'id': 'class', 'label': 'Class / Academic'},
    {'id': 'other', 'label': 'General Audience'},
  ];

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'pptx', 'ppt'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _pickedFilePath = result.files.single.path;
        _pickedFileName = result.files.single.name;
        _pickedFileSize = result.files.single.size;
      });
    }
  }

  Future<void> _handleUpload() async {
    if (_pickedFilePath == null || _pickedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF or PPTX presentation file')),
      );
      return;
    }

    final provider = context.read<SlideCoachProvider>();
    final deckId = await provider.uploadAndStartAnalysis(
      filePath: _pickedFilePath!,
      fileName: _pickedFileName!,
      audience: _selectedAudience,
      timeLimitSeconds: _timeLimitMinutes * 60,
      goal: _goalController.text.trim(),
    );

    if (mounted && deckId != null) {
      context.push('/slide-coach/processing');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SlideCoachProvider>();

    return Scaffold(
      backgroundColor: AppColors.scaffoldOf(context),
      appBar: AppBar(
        title: const Text('Slide Coach AI'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: ThemeToggleButton(size: 38, compact: true),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Description Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppColors.softShadowOf(context),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Multimodal Presentation Coach',
                          style: AppTextStyles.bodyBold.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Upload your deck PDF. AI scans visual slides, calculates time budgets, and writes speech scripts.',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 1. Presentation File Drop Zone
            Text(
              'Presentation Deck (PDF or PPTX)',
              style: AppTextStyles.sectionHeaderOf(context),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: provider.isUploading ? null : _pickPdf,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 28,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardOf(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _pickedFilePath != null
                        ? AppColors.primaryPurple
                        : AppColors.borderOf(context),
                    width: _pickedFilePath != null ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _pickedFilePath != null
                          ? Icons.picture_as_pdf
                          : Icons.cloud_upload_outlined,
                      size: 44,
                      color: _pickedFilePath != null
                          ? AppColors.primaryPurple
                          : AppColors.textSecondaryOf(context),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _pickedFileName ?? 'Tap to select PDF presentation',
                      style: AppTextStyles.bodyBold.copyWith(
                        color: _pickedFilePath != null
                            ? AppColors.textPrimaryOf(context)
                            : AppColors.primaryPurple,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _pickedFileSize != null
                          ? '${(_pickedFileSize! / (1024 * 1024)).toStringAsFixed(1)} MB • Ready'
                          : 'Max 25 MB • 1 to 20 slides',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 2. Audience Selection
            Text(
              'Target Audience',
              style: AppTextStyles.sectionHeaderOf(context),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _audiences.map((aud) {
                final isSelected = _selectedAudience == aud['id'];
                return ChoiceChip(
                  label: Text(aud['label']!),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _selectedAudience = aud['id']!);
                  },
                  selectedColor: AppColors.primaryPurple.withValues(alpha: 0.2),
                  backgroundColor: AppColors.cardOf(context),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.primaryPurple
                        : AppColors.textPrimaryOf(context),
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primaryPurple
                        : AppColors.borderOf(context),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // 3. Time Limit Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Time Limit',
                  style: AppTextStyles.sectionHeaderOf(context),
                ),
                Text(
                  '$_timeLimitMinutes min (${_timeLimitMinutes * 60}s)',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: AppColors.primaryPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: _timeLimitMinutes.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: AppColors.primaryPurple,
              label: '$_timeLimitMinutes min',
              onChanged: (val) =>
                  setState(() => _timeLimitMinutes = val.round()),
            ),

            const SizedBox(height: 16),

            // 4. Primary Presentation Goal
            Text('Primary Goal', style: AppTextStyles.sectionHeaderOf(context)),
            const SizedBox(height: 8),
            TextField(
              controller: _goalController,
              decoration: InputDecoration(
                hintText: 'e.g. Raise seed round, win hackathon, pass thesis',
                filled: true,
                fillColor: AppColors.cardOf(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderOf(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderOf(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primaryPurple,
                    width: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 5. Upload & Analyze Button
            if (provider.isUploading) ...[
              LinearProgressIndicator(
                value: provider.uploadProgress > 0
                    ? provider.uploadProgress
                    : null,
                color: AppColors.primaryPurple,
                backgroundColor: AppColors.borderOf(context),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Uploading deck... ${(provider.uploadProgress * 100).toStringAsFixed(0)}%',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _pickedFilePath != null ? _handleUpload : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                  child: const Text(
                    'Analyze Deck with AI',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],

            if (provider.uploadError != null) ...[
              const SizedBox(height: 12),
              Text(
                'Upload failed: ${provider.uploadError}',
                style: const TextStyle(color: AppColors.dangerRed),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
