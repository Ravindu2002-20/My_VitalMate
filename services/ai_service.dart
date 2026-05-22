import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../database/db_helper.dart';

class AIService {
  // Groq API Key
  static const String _apiKey = AppConfig.groqApiKey;

  // Recommended models:
  // llama-3.1-8b-instant  -> fastest
  // llama-3.3-70b-versatile -> better quality
  static const String _model = 'llama-3.1-8b-instant';

  static final Uri _uri = Uri.parse(
    'https://api.groq.com/openai/v1/chat/completions',
  );

  Future<String> getAIResponse(
    String userMessage, {
    List<Map<String, dynamic>> chatHistory = const [],
  }) async {
    try {
      if (_apiKey.trim().isEmpty ||
          _apiKey == 'YOUR_GROQ_API_KEY') {
        return 'VitalMate AI is not configured yet.';
      }

      final db = DBHelper();

      final user = await db.getFirstUser();

      if (user == null) {
        return "I don't have access to your profile yet.";
      }

      final userId = user['user_id'] as int;

      final health = await db.getHealthProfile(userId);

      http.Response response;

      try {
        response = await http
            .post(
              _uri,
              headers: {
                'Authorization': 'Bearer $_apiKey',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(
                _buildRequestBody(
                  user,
                  health,
                  userMessage,
                  chatHistory,
                ),
              ),
            )
            .timeout(const Duration(seconds: 30));
      } on TimeoutException {
        return 'The AI took too long to respond.';
      }

      Map<String, dynamic> decoded;

      try {
        final raw = jsonDecode(response.body);

        if (raw is! Map<String, dynamic>) {
          return 'Invalid AI response.';
        }

        decoded = raw;
      } catch (_) {
        return 'The AI service returned invalid data.';
      }

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        _logApiError(decoded);
        return _messageForApiError(decoded);
      }

      return _extractResponseText(decoded);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Groq AI Error: $e');
      }

      return 'Connection error. Please try again.';
    }
  }

  Map<String, Object?> _buildRequestBody(
    Map<String, Object?> user,
    Map<String, Object?>? health,
    String userMessage,
    List<Map<String, dynamic>> chatHistory,
  ) {
    final systemPrompt = '''
You are VitalMate AI, a warm and caring health assistant.

Patient profile:
- Name: ${user['full_name']}
- Age: ${user['age'] ?? 'Unknown'}
- Has diabetes: ${health?['has_diabetes'] == 1 ? 'Yes' : 'No'}
- Has hypertension: ${health?['has_hypertension'] == 1 ? 'Yes' : 'No'}
- Existing conditions: ${health?['existing_conditions'] ?? 'None'}
- Current medications: ${health?['medications'] ?? 'None'}
- Allergies: ${health?['allergies'] ?? 'None'}

Rules:
- Be warm and supportive.
- Never diagnose diseases.
- Never recommend medications or doses.
- Ask ONE follow-up question at a time.
- Keep answers concise.
- Encourage doctor consultation for dangerous readings.
- For emergencies, tell the user to contact emergency services immediately.
''';

    final messages = <Map<String, String>>[];

    // System prompt
    messages.add({
      'role': 'system',
      'content': systemPrompt,
    });

    // Previous chat history
    for (final msg in chatHistory) {
      final sender = msg['sender']?.toString() ?? '';
      final text = msg['message']?.toString() ?? '';

      if (text.isEmpty) continue;

      messages.add({
        'role':
            sender == 'user'
                ? 'user'
                : 'assistant',
        'content': text,
      });
    }

    // Current user message
    messages.add({
      'role': 'user',
      'content': userMessage,
    });

    return {
      'model': _model,
      'messages': messages,
      'temperature': 0.7,
      'max_tokens': 700,
    };
  }

  String _extractResponseText(
    Map<String, dynamic> decoded,
  ) {
    final choices = decoded['choices'];

    if (choices is! List || choices.isEmpty) {
      return "I'm sorry, I couldn't process that.";
    }

    final first = choices.first;

    if (first is! Map<String, dynamic>) {
      return "Invalid AI response.";
    }

    final message = first['message'];

    if (message is! Map<String, dynamic>) {
      return "Invalid AI response.";
    }

    final content =
        message['content']?.toString().trim() ?? '';

    if (content.isEmpty) {
      return "I'm sorry, I couldn't process that.";
    }

    return content;
  }

  String _messageForApiError(
    Map<String, dynamic> decoded,
  ) {
    final error = decoded['error'];

    final message =
        error is Map
            ? error['message']?.toString() ?? ''
            : '';

    if (message.contains('Invalid API Key')) {
      return 'Invalid Groq API key.';
    }

    if (message.contains('rate limit')) {
      return 'Rate limit exceeded. Please wait a moment.';
    }

    return 'The AI service could not process your request.';
  }

  void _logApiError(
    Map<String, dynamic> decoded,
  ) {
    if (!kDebugMode) return;

    final error = decoded['error'];

    if (error is Map) {
      debugPrint(
        'Groq API Error: ${error['message']}',
      );
    }
  }
}