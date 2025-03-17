import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:eisenvaultappflutter/services/api/angora_base_service.dart';
import 'package:eisenvaultappflutter/services/upload/upload_constants.dart';
import 'package:eisenvaultappflutter/utils/logger.dart';

/// Handles the chunked upload process for Angora
class AngoraChunkUploader {
  final AngoraBaseService _baseService;
  
  AngoraChunkUploader(this._baseService);
  
  /// Check if a file upload can be resumed
  Future<int> checkUploadStatus(String fileId) async {
    try {
      final url = _baseService.buildUrl('uploads/$fileId/status');
      
      // Create headers with required fields from API docs
      final headers = _baseService.createHeaders();
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // According to API docs, the uploaded bytes are in data.uploaded_bytes
        return data['data']?['uploaded_bytes'] as int? ?? 0;
      }
      
      EVLogger.info('Failed to get upload status', {
        'statusCode': response.statusCode,
        'response': response.body,
      });
      
      return 0;
    } catch (e) {
      EVLogger.error('Failed to check upload status', {
        'fileId': fileId,
        'error': e.toString()
      });
      return 0;
    }
  }
  
  /// Upload a single chunk
  Future<Map<String, dynamic>> uploadChunk({
    required String parentFolderId,
    required String fileId,
    required String fileName,
    required Uint8List chunk,
    required int startByte,
    required int totalFileSize,
    required String mimeType,
    String? description,
  }) async {
    final url = _baseService.buildUrl('uploads');
    
    // Create multipart request
    final request = http.MultipartRequest('POST', Uri.parse(url));
    
    // Add headers
    final headers = _baseService.createHeaders();
    headers.remove('Content-Type'); // Will be set by multipart
    
    // Add Angora upload-specific headers as per API docs
    headers['x-file-id'] = fileId;
    headers['x-file-name'] = fileName;
    headers['x-start-byte'] = startByte.toString();
    headers['x-file-size'] = totalFileSize.toString();
    headers['x-resumable'] = 'true';
    headers['x-relative-path'] = '';
    headers['x-parent-id'] = parentFolderId;
    headers['x-portal'] = 'mobile'; // Indicate this is from the mobile app
    
    request.headers.addAll(headers);
    
    // Add file chunk
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        chunk,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      )
    );
    
    // Add description as comment if provided
    if (description != null && description.isNotEmpty) {
      request.fields['comment'] = description;
    }
    
    EVLogger.debug('Uploading chunk', {
      'fileId': fileId,
      'startByte': startByte,
      'chunkSize': chunk.length,
      'totalSize': totalFileSize
    });
    
    // Send the request with timeout
    final streamedResponse = await request.send().timeout(
      Duration(seconds: UploadConstants.uploadTimeoutSeconds),
      onTimeout: () {
        throw TimeoutException('Chunk upload timed out');
      }
    );
    
    // Read response
    final responseBody = await streamedResponse.stream.bytesToString();
    
    // Check response status - API returns 201 for successful uploads
    if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
      EVLogger.debug('Chunk upload successful', {
        'statusCode': streamedResponse.statusCode,
        'startByte': startByte,
        'endByte': startByte + chunk.length
      });
      
      return jsonDecode(responseBody);
    } else {
      EVLogger.error('Chunk upload failed', {
        'statusCode': streamedResponse.statusCode,
        'response': responseBody,
        'startByte': startByte
      });
      
      throw Exception('Chunk upload failed: ${streamedResponse.statusCode}');
    }  }
}