import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/resume_model.dart';
import '../services/resume_service.dart';
import '../services/resume_download_service.dart';

class ResumeViewWidget extends StatefulWidget {
  final String userId;

  const ResumeViewWidget({super.key, required this.userId});

  @override
  State<ResumeViewWidget> createState() => _ResumeViewWidgetState();
}

class _ResumeViewWidgetState extends State<ResumeViewWidget> {
  final _resumeService = ResumeService();
  final _downloadService = ResumeDownloadService();

  ResumeModel? _resume;
  bool _isLoading = true;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _downloadedFilePath;

  @override
  void initState() {
    super.initState();
    _loadResume();
  }

  Future<void> _loadResume() async {
    try {
      final resume =
          await _resumeService.fetchResumeByUserId(widget.userId);
      if (mounted) setState(() => _resume = resume);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadResume() async {
    if (_resume?.fileUrl == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      final fileName = 'resume_${widget.userId}.pdf';
      final path = await _downloadService.downloadResume(
        url: _resume!.fileUrl!,
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
    } 
    catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } 
    
    finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadedFilePath = null;
          _downloadProgress = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_resume == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Row(children: [
          Icon(Icons.info_outline, color: Colors.grey),
          SizedBox(width: 8),
          Text('No resume added yet.',
              style: TextStyle(color: Colors.grey)),
        ]),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.description_outlined),
              const SizedBox(width: 8),
              Text('Resume',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 24),

            // PDF resume
            if (_resume!.fileUrl != null) ...[
              const Text('Uploaded Resume',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(_resume!.fileUrl!),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.visibility),
                    label: const Text('View PDF'),
                  ),
                  if (_isDownloading)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Downloading...',
                            style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 140,
                          child: LinearProgressIndicator(
                              value: _downloadProgress),
                        ),
                      ],
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _downloadedFilePath != null
                          ? () => _downloadService
                              .openFile(_downloadedFilePath!)
                          : _downloadResume,
                      icon: Icon(_downloadedFilePath != null
                          ? Icons.folder_open
                          : Icons.download),
                      label: Text(_downloadedFilePath != null
                          ? 'Open'
                          : 'Download'),
                    ),
                ],
              ),
            ],

            // Form resume
            if (_resume!.fileUrl == null) ...[
              _viewSection('Full Name', _resume!.fullName),
              _viewSection('Summary', _resume!.summary),
              _viewSection('Work Experience', _resume!.experience),
              _viewSection('Education', _resume!.education),
              if (_resume!.skills != null) ...[
                const Text('Skills',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _resume!.skills!
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .map((skill) => Chip(label: Text(skill)))
                      .toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _viewSection(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}