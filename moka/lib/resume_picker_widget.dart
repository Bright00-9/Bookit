import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'resume_model.dart';
import '/services/resume_service.dart';
import '/services/resume_download_service.dart';

class ResumePickerWidget extends StatefulWidget {
  final Function(ResumeModel?) onResumeReady;

  const ResumePickerWidget({super.key, required this.onResumeReady});

  @override
  State<ResumePickerWidget> createState() => _ResumePickerWidgetState();
}

class _ResumePickerWidgetState extends State<ResumePickerWidget> {
  final _resumeService = ResumeService();
  final _downloadService = ResumeDownloadService();

  bool _useForm = false;
  bool _isUploading = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isLoading = true;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _uploadedFileUrl;
  String? _localFilePath;
  String? _downloadedFilePath;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _educationCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExistingResume();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _summaryCtrl.dispose();
    _experienceCtrl.dispose();
    _educationCtrl.dispose();
    _skillsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingResume() async {
    try {
      final resume = await _resumeService.fetchResume();
      if (resume != null && mounted) {
        setState(() {
          if (resume.fileUrl != null) {
            _useForm = false;
            _uploadedFileUrl = resume.fileUrl;
          } else {
            _useForm = true;
            _nameCtrl.text = resume.fullName ?? '';
            _summaryCtrl.text = resume.summary ?? '';
            _experienceCtrl.text = resume.experience ?? '';
            _educationCtrl.text = resume.education ?? '';
            _skillsCtrl.text = resume.skills ?? '';
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();

    setState(() {
      _isUploading = true;
      _localFilePath = file.path;
    });

    try {
      // Upload via service — no Supabase client in widget
      final url = await _resumeService.uploadResumePdf(
        bytes: bytes,
        fileName: file.name,
      );

      setState(() => _uploadedFileUrl = url);

      final resume = ResumeModel(fileUrl: url);
      setState(() => _isSaving = true);
      await _resumeService.saveResume(resume);
      widget.onResumeReady(resume);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Resume uploaded and saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() {
        _isUploading = false;
        _isSaving = false;
      });
    }
  }
  
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final resume = ResumeModel(
      fullName: _nameCtrl.text.trim(),
      summary: _summaryCtrl.text.trim(),
      experience: _experienceCtrl.text.trim(),
      education: _educationCtrl.text.trim(),
      skills: _skillsCtrl.text.trim(),
    );

    setState(() => _isSaving = true);

    try {
      await _resumeService.saveResume(resume);
      widget.onResumeReady(resume);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Resume saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteResume() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Resume'),
        content: const Text(
            'Are you sure you want to delete your resume? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      await _resumeService.deleteResume();
      setState(() {
        _uploadedFileUrl = null;
        _localFilePath = null;
        _downloadedFilePath = null;
        _nameCtrl.clear();
        _summaryCtrl.clear();
        _experienceCtrl.clear();
        _educationCtrl.clear();
        _skillsCtrl.clear();
      });
      widget.onResumeReady(null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Resume deleted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _downloadResume() async {
    if (_uploadedFileUrl == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      final fileName =
          'resume_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final path = await _downloadService.downloadResume(
        url: _uploadedFileUrl!,
        fileName: fileName,
        onProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _downloadProgress = received / total);
          }
        },
      );

      setState(() => _downloadedFilePath = path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Resume downloaded!'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () async {
                try {
                  await _downloadService.openFile(path!);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not open: $e')),
                    );
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() {
        _isDownloading = false;
        _downloadProgress = 0;
      });
    }
  }

  void _previewPdf() {
    if (_localFilePath != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _PdfPreviewScreen(filePath: _localFilePath!),
        ),
      );
    } else if (_uploadedFileUrl != null) {
      launchUrl(Uri.parse(_uploadedFileUrl!),
          mode: LaunchMode.externalApplication);
    }
  }

  void _previewFormResume() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                _nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'No Name',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Divider(height: 24),
              _previewSection('Summary', _summaryCtrl.text),
              _previewSection('Work Experience', _experienceCtrl.text),
              _previewSection('Education', _educationCtrl.text),
              if (_skillsCtrl.text.isNotEmpty) ...[
                const Text('Skills',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _skillsCtrl.text
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .map((skill) => Chip(label: Text(skill)))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewSection(String title, String content) {
    if (content.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.grey)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }

  bool get _hasResume =>
      _uploadedFileUrl != null || _nameCtrl.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle tabs
        Row(
          children: [
            ChoiceChip(
              label: const Text('Upload PDF'),
              selected: !_useForm,
              onSelected: (_) => setState(() => _useForm = false),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Fill In'),
              selected: _useForm,
              onSelected: (_) => setState(() => _useForm = true),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Upload section ──
        if (!_useForm) ...[
          if (_isUploading)
            const Row(children: [
              CircularProgressIndicator(),
              SizedBox(width: 12),
              Text('Uploading...'),
            ])
          else if (_uploadedFileUrl != null || _localFilePath != null) ...[
            Row(children: const [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Resume uploaded'),
            ]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _previewPdf,
                  icon: const Icon(Icons.visibility),
                  label: const Text('Preview'),
                ),
                if (_isDownloading)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Downloading...',
                          style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 160,
                        child: LinearProgressIndicator(
                            value: _downloadProgress),
                      ),
                    ],
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _downloadedFilePath != null
                        ? () =>
                            _downloadService.openFile(_downloadedFilePath!)
                        : _downloadResume,
                    icon: Icon(_downloadedFilePath != null
                        ? Icons.folder_open
                        : Icons.download),
                    label: Text(_downloadedFilePath != null
                        ? 'Open File'
                        : 'Download'),
                  ),
                OutlinedButton.icon(
                  onPressed: _pickAndUploadFile,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Replace'),
                ),
                OutlinedButton.icon(
                  onPressed: _isDeleting ? null : _deleteResume,
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Delete',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ] else
            ElevatedButton.icon(
              onPressed: _pickAndUploadFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Select PDF'),
            ),
        ],

        // ── Form section ──
        if (_useForm)
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Full Name'),
                  validator: (v) =>
                      v!.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _summaryCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Summary'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _experienceCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Work Experience'),
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _educationCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Education'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _skillsCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Skills (comma-separated)'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (_hasResume) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _previewFormResume,
                          icon: const Icon(Icons.visibility),
                          label: const Text('Preview'),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _submitForm,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Text('Save Resume'),
                      ),
                    ),
                    if (_hasResume) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isDeleting ? null : _deleteResume,
                        icon: _isDeleting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.delete,
                                color: Colors.red),
                        tooltip: 'Delete Resume',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// Full screen PDF viewer
class _PdfPreviewScreen extends StatelessWidget {
  final String filePath;

  const _PdfPreviewScreen({required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resume Preview'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PDFView(
        filePath: filePath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
      ),
    );
  }
}