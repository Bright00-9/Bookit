import 'dart:io';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ResumeDownloadService {
  final Dio _dio = Dio();

  Future<String?> downloadResume({
    required String url,
    required String fileName,
    void Function(int received, int total)? onProgress,
  }) async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (status.isDenied) throw Exception('Storage permission denied');
    }

    final dir = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();

    if (dir == null) throw Exception('Could not access storage');

    final savePath = '${dir.path}/$fileName';

    await _dio.download(
      url,
      savePath,
      onReceiveProgress: onProgress,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
      ),
    );

    return savePath;
  }

  Future<void> openFile(String filePath) async {
    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      throw Exception('Could not open file: ${result.message}');
    }
  }
}