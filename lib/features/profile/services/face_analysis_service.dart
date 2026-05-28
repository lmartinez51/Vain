/// @file face_analysis_service.dart
/// @brief Service for analyzing facial features from an image using the OpenAI API.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// @brief Service class to handle facial analysis using OpenAI's GPT-5-nano model.
class FaceAnalysisService {
  final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  final String _baseUrl = "https://api.openai.com/v1/responses";

  /// @brief Initializes a new instance of [FaceAnalysisService].
  FaceAnalysisService();

  /// @brief Analyzes a face from an image file and extracts face shape and key features.
  /// @param imagePath The local file path to the image.
  /// @return A map containing 'faceShape' and 'keyFeatures'.
  Future<Map<String, dynamic>> analyzeFace(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_apiKey",
      },
      body: jsonEncode({
        "model": "gpt-5-nano",
        "input": [
          {
            "role": "user",
            "content": [
              {
                "type": "input_text",
                "text":
                    "Analyze face shape and features. Return ONLY a JSON object with: 'faceShape' (string: oval, round, square, heart, diamond, or pear) and 'keyFeatures' (list of 3 strings in English describing prominent traits). No prose, just the JSON."
              },
              {
                "type": "input_image",
                "image_url": "data:image/jpeg;base64,$base64Image",
              },
            ],
          }
        ],
        // 🟢 Eliminamos 'output' y 'instructions' de aquí si el modelo se queja
        // El formato JSON se pide en el 'input_text' para máxima compatibilidad
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);

      try {
        String? rawContent;

        // 🟢 ESCANEO INTELIGENTE: Buscamos en la lista 'output' el objeto tipo 'message'
        if (data['output'] != null && data['output'] is List) {
          for (var item in data['output']) {
            if (item['type'] == 'message' && item['content'] != null) {
              // El texto vive en el primer elemento del contenido
              rawContent = item['content'][0]['text'];
              break; // Ya lo encontramos, salimos del bucle
            }
          }
        }

        if (rawContent == null) {
          throw "No se encontró un bloque tipo 'message' con texto.";
        }

        final cleanJson =
            rawContent.replaceAll('```json', '').replaceAll('```', '').trim();
        debugPrint("📥 ADN Facial detectado: $cleanJson");

        return jsonDecode(cleanJson);
      } catch (e) {
        debugPrint("❌ Error de extracción: $e");
        throw Exception("Error parseando respuesta de IA: $e");
      }
    } else {
      throw Exception("Error en el análisis facial: ${response.body}");
    }
  }
}
