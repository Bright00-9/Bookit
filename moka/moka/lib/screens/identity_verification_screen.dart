import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../services/identity_verification_service.dart';

class IdentityVerificationScreen extends StatefulWidget {
  final bool isBlocking;
  final VoidCallback? onVerified;

  const IdentityVerificationScreen({
    super.key,
    this.isBlocking = false,
    this.onVerified,
  });

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen> {
  final _service = IdentityVerificationService();
  final _picker = ImagePicker();
  final _idNumberCtrl = TextEditingController();

  Map<String, dynamic>? _existing;
  IdentityStatus _status = IdentityStatus.unverified;
  bool _isLoading = true;
  bool _isSubmittingId = false;
  bool _isUploadingVideo = false;

  // ── Steps ──────────────────────────────────────────────
  // Step 1: ID verification
  // Step 2: Work video upload
  int _currentStep = 0; // 0 = ID, 1 = Video

  // ── ID fields ──────────────────────────────────────────
  String _selectedIdType = 'GHANA_CARD';
  String _selectedCountry = 'GH';

  final List<Map<String, String>> _idTypes = [
    {
      'label': 'Ghana Card (NIA)',
      'type': 'GHANA_CARD',
      'country': 'GH',
      'hint': 'GHA-XXXXXXXXX-X',
    },
    {
      'label': 'Nigeria NIN',
      'type': 'NIN',
      'country': 'NG',
      'hint': 'XXXXXXXXXXX',
    },
    {
      'label': 'Nigeria BVN',
      'type': 'BVN',
      'country': 'NG',
      'hint': 'XXXXXXXXXXX',
    },
    {
      'label': 'Kenya National ID',
      'type': 'NATIONAL_ID',
      'country': 'KE',
      'hint': 'XXXXXXXX',
    },
  ];

  File? _selfieFile;
  File? _idPhotoFile;

  // ── Video fields ───────────────────────────────────────
  File? _videoFile;
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  String? _existingVideoUrl;
  String? _videoStatus;
  String? _videoRejectionReason;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _idNumberCtrl.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final v = await _service.fetchVerification();
      final status = await _service.fetchStatus();

      if (mounted) {
        setState(() {
          _existing = v;
          _status = status;
          _existingVideoUrl = v?['work_video_url'];
          _videoStatus = v?['work_video_status'];
          _videoRejectionReason =
              v?['work_video_rejection_reason'];

          // If ID already submitted, go to video step
          if (v != null &&
              (status == IdentityStatus.pending ||
                  status == IdentityStatus.autoPassed ||
                  status == IdentityStatus.verified)) {
            _currentStep = 1;
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Pick selfie ────────────────────────────────────────
  Future<void> _pickSelfie() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _selfieFile = File(picked.path));
  }

  // ── Pick ID photo ──────────────────────────────────────
  Future<void> _pickIdPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _idPhotoFile = File(picked.path));
  }

  // ── Pick work video ────────────────────────────────────
  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );
    if (picked == null) return;

    final file = File(picked.path);
    final sizeBytes = await file.length();

    // Max 100MB
    if (sizeBytes > 100 * 1024 * 1024) {
      _snack('Video too large. Please keep it under 100MB.');
      return;
    }

    // Dispose old controller
    await _videoController?.dispose();

    final controller =
        VideoPlayerController.file(file);
    await controller.initialize();

    // Check duration <= 60 seconds
    final duration = controller.value.duration;
    if (duration.inSeconds > 60) {
      await controller.dispose();
      _snack(
          'Video too long. Maximum 60 seconds allowed.');
      return;
    }

    if (mounted) {
      setState(() {
        _videoFile = file;
        _videoController = controller;
        _videoInitialized = true;
      });
    }
  }

  // ── Record video directly ──────────────────────────────
  Future<void> _recordVideo() async {
    final picked = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 60),
    );
    if (picked == null) return;

    final file = File(picked.path);
    await _videoController?.dispose();

    final controller =
        VideoPlayerController.file(file);
    await controller.initialize();

    if (mounted) {
      setState(() {
        _videoFile = file;
        _videoController = controller;
        _videoInitialized = true;
      });
    }
  }

  // ── Submit ID ──────────────────────────────────────────
  Future<void> _submitId() async {
    if (_idNumberCtrl.text.trim().isEmpty) {
      _snack('Please enter your ID number');
      return;
    }
    if (_selfieFile == null) {
      _snack('Please take a selfie');
      return;
    }
    if (_idPhotoFile == null) {
      _snack('Please upload your ID photo');
      return;
    }

    setState(() => _isSubmittingId = true);

    try {
      final selfieBytes =
          await _selfieFile!.readAsBytes();
      final idBytes =
          await _idPhotoFile!.readAsBytes();

      final selfieUrl = await _service
          .uploadVerificationPhoto(
              selfieBytes, 'selfie');
      final idPhotoUrl = await _service
          .uploadVerificationPhoto(
              idBytes, 'id_photo');

      final result =
          await _service.submitVerification(
        idType: _selectedIdType,
        idNumber: _idNumberCtrl.text.trim(),
        country: _selectedCountry,
        selfieUrl: selfieUrl,
        idPhotoUrl: idPhotoUrl,
      );

      if (mounted) {
        await _loadExisting();
        // Move to video step
        setState(() => _currentStep = 1);

        _showStepDialog(
          title: result['auto_passed'] == true
              ? 'ID Check Passed'
              : 'ID Submitted',
          message:
              'Now please upload a short video of you working to complete your verification.',
          buttonLabel: 'Next: Upload Video',
        );
      }
    } catch (e) {
      _snack('Submission failed: $e');
    } finally {
      if (mounted)
        setState(() => _isSubmittingId = false);
    }
  }

  // ── Submit video ───────────────────────────────────────
  Future<void> _submitVideo() async {
    if (_videoFile == null) {
      _snack('Please select or record a video first');
      return;
    }

    setState(() {
      _isUploadingVideo = true;
      _uploadProgress = 0;
    });

    try {
      // Upload to B2 via Edge Function
      final result =
          await _service.uploadWorkVideo(_videoFile!);

      // Save record to Supabase
      await _service.saveVideoRecord(
        videoUrl: result['download_url'],
        b2FileId: result['file_id'],
      );

      if (mounted) {
        setState(() {
          _existingVideoUrl = result['download_url'];
          _videoStatus = 'pending';
        });

        _showStepDialog(
          title: 'Video Submitted',
          message:
              'Your work video has been submitted for admin review. You will be notified once approved.',
          buttonLabel: 'Done',
          onDone: () {
            if (widget.isBlocking) {
              Navigator.pop(context);
            }
          },
        );
      }
    } catch (e) {
      _snack('Video upload failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingVideo = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  void _showStepDialog({
    required String title,
    required String message,
    required String buttonLabel,
    VoidCallback? onDone,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 13,
                  height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onDone?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFFF6B00),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(buttonLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: widget.isBlocking
            ? const SizedBox.shrink()
            : IconButton(
                onPressed: () =>
                    Navigator.pop(context),
                icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20),
              ),
        title: const Text('Identity Verification',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFFFF6B00)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // ── Step indicator ─────────────────
                  _buildStepIndicator(),
                  const SizedBox(height: 20),

                  // ── Status banner ──────────────────
                  _buildStatusBanner(),
                  const SizedBox(height: 20),

                  // ── Step 0: ID Verification ────────
                  if (_currentStep == 0 &&
                      (_status ==
                              IdentityStatus
                                  .unverified ||
                          _status ==
                              IdentityStatus
                                  .rejected)) ...[
                    _buildInfoCard(),
                    const SizedBox(height: 20),
                    _buildIdForm(),
                  ],

                  // ── Step 1: Video Upload ───────────
                  if (_currentStep == 1) ...[
                    _buildVideoStep(),
                  ],

                  // ── Resubmit if rejected ───────────
                  if (_status ==
                      IdentityStatus.rejected) ...[
                    const SizedBox(height: 16),
                    _buildResubmitButton(),
                  ],
                ],
              ),
            ),
    );
  }

  // ─── Step indicator ───────────────────────────────────
  Widget _buildStepIndicator() {
    return Row(
      children: [
        _stepDot(
          index: 0,
          label: 'ID Check',
          icon: Icons.badge_outlined,
        ),
        Expanded(
          child: Container(
            height: 2,
            color: _currentStep >= 1
                ? const Color(0xFFFF6B00)
                : const Color(0xFF2A2A2A),
          ),
        ),
        _stepDot(
          index: 1,
          label: 'Work Video',
          icon: Icons.videocam_outlined,
        ),
      ],
    );
  }

  Widget _stepDot({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isActive = _currentStep == index;
    final isDone = _currentStep > index;

    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDone
                ? const Color(0xFF4CAF50)
                : isActive
                    ? const Color(0xFFFF6B00)
                    : const Color(0xFF1A1A1A),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDone
                  ? const Color(0xFF4CAF50)
                  : isActive
                      ? const Color(0xFFFF6B00)
                      : const Color(0xFF2A2A2A),
              width: 2,
            ),
          ),
          child: Icon(
            isDone ? Icons.check : icon,
            color: isDone || isActive
                ? Colors.white
                : const Color(0xFF555555),
            size: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive || isDone
                ? Colors.white
                : const Color(0xFF555555),
            fontSize: 11,
            fontWeight: isActive
                ? FontWeight.w700
                : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // ─── Status banner ────────────────────────────────────
  Widget _buildStatusBanner() {
    // Show video-specific status on step 2
    if (_currentStep == 1 &&
        _existingVideoUrl != null) {
      Color color;
      String title;
      String subtitle;

      switch (_videoStatus) {
        case 'approved':
          color = const Color(0xFF4CAF50);
          title = 'Video Approved';
          subtitle =
              'Your work video has been approved by our team.';
          break;
        case 'rejected':
          color = const Color(0xFFE53935);
          title = 'Video Rejected';
          subtitle = _videoRejectionReason ??
              'Your video was rejected. Please upload a new one.';
          break;
        default:
          color = const Color(0xFFFF9800);
          title = 'Video Under Review';
          subtitle =
              'Our admin team is reviewing your work video. This usually takes 24 hours.';
      }

      return _statusCard(
          color: color,
          title: title,
          subtitle: subtitle);
    }

    // Default ID status banner
    Color color;
    IconData icon;

    switch (_status) {
      case IdentityStatus.verified:
        color = const Color(0xFF4CAF50);
        icon = Icons.verified_user;
        break;
      case IdentityStatus.autoPassed:
        color = const Color(0xFF2196F3);
        icon = Icons.auto_awesome;
        break;
      case IdentityStatus.pending:
        color = const Color(0xFFFF9800);
        icon = Icons.hourglass_top;
        break;
      case IdentityStatus.rejected:
        color = const Color(0xFFE53935);
        icon = Icons.cancel_outlined;
        break;
      default:
        color = const Color(0xFF888888);
        icon = Icons.shield_outlined;
    }

    return _statusCard(
      color: color,
      title: _status.label,
      subtitle: _statusDescription(),
      icon: icon,
    );
  }

  Widget _statusCard({
    required Color color,
    required String title,
    required String subtitle,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          if (icon != null)
            Icon(icon, color: color, size: 26),
          if (icon != null) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 12,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusDescription() {
    switch (_status) {
      case IdentityStatus.verified:
        return 'Your identity is fully verified. Upload your work video to complete verification.';
      case IdentityStatus.autoPassed:
        return 'ID auto check passed. Now upload your work video for admin review.';
      case IdentityStatus.pending:
        return 'ID submitted and under review. Now upload your work video.';
      case IdentityStatus.rejected:
        return _existing?['rejection_reason'] ??
            'Verification rejected. Please resubmit.';
      default:
        return 'Complete both steps to start posting and accepting jobs.';
    }
  }

  // ─── Info card ────────────────────────────────────────
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline,
                  color: Color(0xFFFF6B00), size: 18),
              SizedBox(width: 8),
              Text('Two-step verification',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow(
              Icons.badge_outlined, 'Submit your national ID and selfie'),
          _infoRow(
              Icons.videocam_outlined, 'Upload a short work video (max 60 seconds)'),
          _infoRow(
              Icons.admin_panel_settings_outlined, 'Admin reviews and approves you'),
          _infoRow(
              Icons.work_outline, 'Start posting and accepting jobs'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF888888)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ─── ID Form ──────────────────────────────────────────
  Widget _buildIdForm() {
    final selectedType = _idTypes.firstWhere(
      (t) => t['type'] == _selectedIdType,
      orElse: () => _idTypes.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Select ID Type'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _idTypes.map((t) {
            final selected =
                _selectedIdType == t['type'];
            return GestureDetector(
              onTap: () => setState(() {
                _selectedIdType = t['type']!;
                _selectedCountry = t['country']!;
                _idNumberCtrl.clear();
              }),
              child: AnimatedContainer(
                duration: const Duration(
                    milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFFF6B00)
                          .withOpacity(0.15)
                      : const Color(0xFF1A1A1A),
                  borderRadius:
                      BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFFF6B00)
                        : const Color(0xFF2A2A2A),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  t['label']!,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFFFF6B00)
                        : const Color(0xFF888888),
                    fontSize: 12,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        _buildLabel(
            '${selectedType['label']} Number'),
        const SizedBox(height: 8),
        TextField(
          controller: _idNumberCtrl,
          style: const TextStyle(
              color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: selectedType['hint'],
            hintStyle: const TextStyle(
                color: Color(0xFF555555)),
            prefixIcon: const Icon(
                Icons.badge_outlined,
                color: Color(0xFF888888),
                size: 20),
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: Color(0xFF2A2A2A)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: Color(0xFF2A2A2A)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: Color(0xFFFF6B00),
                  width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
          ),
        ),
        const SizedBox(height: 20),

        _buildLabel('Take a Selfie'),
        const SizedBox(height: 4),
        const Text(
          'Look straight at the camera in good lighting.',
          style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 12),
        ),
        const SizedBox(height: 10),
        _buildPhotoBox(
          file: _selfieFile,
          icon: Icons.camera_alt_outlined,
          label: 'Open Camera',
          onTap: _pickSelfie,
        ),
        const SizedBox(height: 20),

        _buildLabel('Upload ID Photo'),
        const SizedBox(height: 4),
        const Text(
          'All text on the ID must be clearly readable.',
          style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 12),
        ),
        const SizedBox(height: 10),
        _buildPhotoBox(
          file: _idPhotoFile,
          icon: Icons.upload_file_outlined,
          label: 'Upload ID Photo',
          onTap: _pickIdPhoto,
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed:
                _isSubmittingId ? null : _submitId,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  const Color(0xFFFF6B00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _isSubmittingId
                ? const Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5),
                      ),
                      SizedBox(width: 12),
                      Text('Verifying ID...',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  FontWeight.w700)),
                    ],
                  )
                : const Text(
                    'Submit ID & Continue',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        const Center(
          child: Text(
            'Powered by Smile Identity',
            style: TextStyle(
                color: Color(0xFF555555),
                fontSize: 11),
          ),
        ),
      ],
    );
  }

  // ─── Video Step ───────────────────────────────────────
  Widget _buildVideoStep() {
    final videoApproved = _videoStatus == 'approved';
    final videoRejected = _videoStatus == 'rejected';
    final videoPending = _videoStatus == 'pending' &&
        _existingVideoUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Guidelines ────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.videocam_outlined,
                      color: Color(0xFFFF6B00),
                      size: 18),
                  SizedBox(width: 8),
                  Text('Video Guidelines',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ],
              ),
              const SizedBox(height: 10),
              _infoRow(Icons.videocam_outlined,
                  'Show yourself working in your skill area'),
              _infoRow(Icons.schedule,
                  'Maximum 60 seconds'),
              _infoRow(Icons.lightbulb_outline,
                  'Good lighting and clear audio'),
              _infoRow(Icons.block,
                  'No inappropriate content'),
              _infoRow(Icons.phone_android,
                  'Hold phone steady — landscape recommended'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Video picker ──────────────────────────
        if (!videoApproved && !videoPending) ...[
          _buildLabel('Your Work Video'),
          const SizedBox(height: 10),

          // Video preview or picker
          if (_videoInitialized &&
              _videoController != null)
            _buildVideoPreview()
          else if (_existingVideoUrl != null &&
              videoRejected)
            _buildVideoRejectedBox()
          else
            _buildVideoPickerBox(),

          const SizedBox(height: 16),

          // Pick / Record buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(
                      Icons.upload_file_outlined,
                      size: 16),
                  label: const Text('Choose Video'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        const Color(0xFFFF6B00),
                    side: const BorderSide(
                        color: Color(0xFFFF6B00)),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                                12)),
                    padding:
                        const EdgeInsets.symmetric(
                            vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _recordVideo,
                  icon: const Icon(
                      Icons.videocam_outlined,
                      size: 16),
                  label: const Text('Record Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFFF6B00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                                12)),
                    padding:
                        const EdgeInsets.symmetric(
                            vertical: 12),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Upload button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isUploadingVideo ||
                      _videoFile == null
                  ? null
                  : _submitVideo,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFFFF6B00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isUploadingVideo
                  ? Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5),
                        ),
                        const SizedBox(height: 4),
                        const Text('Uploading...',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    FontWeight.w600)),
                      ],
                    )
                  : const Text(
                      'Submit Work Video',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w700),
                    ),
            ),
          ),
        ],

        // ── Video pending ─────────────────────────
        if (videoPending)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800)
                  .withOpacity(0.1),
              borderRadius:
                  BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFFF9800)
                      .withOpacity(0.4)),
            ),
            child: const Column(
              children: [
                Icon(Icons.hourglass_top,
                    color: Color(0xFFFF9800),
                    size: 36),
                SizedBox(height: 12),
                Text('Video Under Review',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                SizedBox(height: 6),
                Text(
                  'Our team is reviewing your work video. You will be notified once it is approved. This usually takes up to 24 hours.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 13,
                      height: 1.4),
                ),
              ],
            ),
          ),

        // ── Video approved ────────────────────────
        if (videoApproved)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50)
                  .withOpacity(0.1),
              borderRadius:
                  BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF4CAF50)
                      .withOpacity(0.4)),
            ),
            child: const Column(
              children: [
                Icon(Icons.verified_user,
                    color: Color(0xFF4CAF50),
                    size: 36),
                SizedBox(height: 12),
                Text('Fully Verified!',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                SizedBox(height: 6),
                Text(
                  'Both your ID and work video have been approved. You can now post jobs and accept applications.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 13,
                      height: 1.4),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildVideoPreview() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio:
                _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          ),
        ),
        // Play/pause overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _videoController!.value.isPlaying
                    ? _videoController!.pause()
                    : _videoController!.play();
              });
            },
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _videoController!
                          .value.isPlaying
                      ? 0
                      : 1,
                  duration: const Duration(
                      milliseconds: 200),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 30),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Duration badge
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _formatDuration(
                  _videoController!.value.duration),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
        // Replace button
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () {
              _videoController?.dispose();
              setState(() {
                _videoFile = null;
                _videoController = null;
                _videoInitialized = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close,
                  color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPickerBox() {
    return GestureDetector(
      onTap: _pickVideo,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF2A2A2A),
              width: 1.5),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined,
                color: Color(0xFF555555), size: 40),
            SizedBox(height: 10),
            Text('Tap to select a video',
                style: TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 13)),
            SizedBox(height: 4),
            Text('Max 60 seconds',
                style: TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoRejectedBox() {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE53935).withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFE53935)
                .withOpacity(0.4)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.video_library_outlined,
              color: Color(0xFFE53935), size: 30),
          const SizedBox(height: 6),
          const Text('Previous video rejected',
              style: TextStyle(
                  color: Color(0xFFE53935),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          if (_videoRejectionReason != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
              child: Text(
                _videoRejectionReason!,
                style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          await _service.clearRejection();
          await _loadExisting();
          setState(() => _currentStep = 0);
        },
        icon: const Icon(Icons.refresh,
            color: Color(0xFFFF6B00)),
        label: const Text('Start Over',
            style: TextStyle(
                color: Color(0xFFFF6B00),
                fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(
              color: Color(0xFFFF6B00)),
          shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(
              vertical: 14),
        ),
      ),
    );
  }

  Widget _buildPhotoBox({
    required File? file,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 130,
        width: double.infinity,
        decoration: BoxDecoration(
          color: file != null
              ? const Color(0xFF4CAF50)
                  .withOpacity(0.05)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: file != null
                ? const Color(0xFF4CAF50)
                : const Color(0xFF2A2A2A),
            width: 1.5,
          ),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius:
                    BorderRadius.circular(12),
                child: Image.file(file,
                    fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: 30,
                      color:
                          const Color(0xFF888888)),
                  const SizedBox(height: 8),
                  Text(label,
                      style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 13)),
                ],
              ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s =
        (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(
            color: Color(0xFFCCCCCC),
            fontSize: 14,
            fontWeight: FontWeight.w600));
  }
}