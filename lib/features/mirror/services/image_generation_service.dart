/// @file image_generation_service.dart
/// @brief Service for generating AI images and makeup edits via the OpenAI API.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vain_app/features/mirror/models/visual_brief.dart';

/// @brief A service class that handles HTTP requests to OpenAI's image editing endpoint.
class ImageGenerationService {
  final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  static const String _endpoint = 'https://api.openai.com/v1/images/edits';

  /// @brief Initializes a new instance of [ImageGenerationService] and validates the API key.
  ImageGenerationService() {
    if (_apiKey.isEmpty) {
      throw Exception(
        'OPENAI_API_KEY no está definido en el entorno',
      );
    }
  }

  /// @brief Sends an image edit request to OpenAI based on a provided visual brief.
  /// @param brief The structured visual brief containing makeup and style instructions.
  /// @param userPhotoPath The local file path to the user's base photo.
  /// @return A completed [Future] containing the local file path to the generated image.
  Future<String> generateImage({
    required VisualBrief brief,
    required String userPhotoPath,
  }) async {
    final file = File(userPhotoPath);
    if (!await file.exists()) {
      throw Exception('Physical photo file missing at path: $userPhotoPath');
    }

    // 1. Cambiamos el endpoint a /v1/images/edits
    final uri = Uri.parse(_endpoint);

    // 2. Usamos MultipartRequest para enviar archivos reales
    var request = http.MultipartRequest('POST', uri);

    // 3. Headers
    request.headers.addAll({
      'Authorization': 'Bearer $_apiKey',
      // El Content-Type se establece automáticamente como multipart/form-data
    });

    // 4. Campos del Formulario (Basado en la documentación que encontraste)
    request.fields['model'] = 'gpt-image-1.5';
    request.fields['prompt'] = _buildMultimodalPrompt(brief);
    request.fields['quality'] = 'high'; // Calidad superior para maquillaje
    request.fields['output_format'] = 'jpeg'; // O webp si prefieres
    request.fields['size'] = '1024x1024';

    // Nota: input_fidelity es opcional, pero ayuda a mantener los rasgos
    // Aunque mencionaste que es para v1, suele ser compatible como guía de esfuerzo
    // request.fields['input_fidelity'] = 'high';

    // 5. Adjuntamos la imagen física
    request.files.add(await http.MultipartFile.fromPath(
      'image',
      file.path,
      contentType: MediaType('image', 'jpeg'),
    ));

    debugPrint("🚀 [Images Edit API] Enviando petición...");

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint("🔍 [Images Edit API] Status: ${response.statusCode}");

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error en Images Edit API: ${response.body}');
    }

    // 6. Procesar la respuesta
    final decoded = jsonDecode(response.body);

    // 🔥 LOGGING: Monitoreo de Tokens
    // (Útil para optimizar costos de la API)
    if (decoded['usage'] != null) {
      debugPrint(
          '💰 [Images Edit API] Tokens Usados: ${decoded['usage']['total_tokens']}');
    }

    try {
      if (decoded['data'] != null && (decoded['data'] as List).isNotEmpty) {
        // Extraemos el string Base64 puro
        final String b64Data = decoded['data'][0]['b64_json'];

        // 💾 ALMACENAMIENTO FÍSICO
        // Convertimos a archivo real inmediatamente para evitar consumo de RAM
        final savedPath = await _saveBase64ToDisk(b64Data);
        debugPrint('✅ [ImageGenerationService] Imagen guardada en: $savedPath');

        return savedPath;
      } else {
        throw Exception('La respuesta de OpenAI no contiene datos de imagen.');
      }
    } catch (e) {
      debugPrint('❌ Error parseando/guardando imagen: $e');
      throw Exception('Fallo al procesar la respuesta de imagen: $e');
    }
  }

  /// @brief Converts a Base64 image string into a physical file and cleans up old generated styles.
  /// @param base64String The raw Base64 string payload from the AI.
  /// @return A completed [Future] containing the local file path of the saved image.
  Future<String> _saveBase64ToDisk(String base64String) async {
    final directory = await getApplicationDocumentsDirectory();

    // 🧹 LIMPIEZA AUTOMÁTICA: Borrar estilos antiguos para ahorrar espacio
    try {
      final List<FileSystemEntity> files = directory.listSync();
      for (var file in files) {
        if (file is File &&
            file.path.split(Platform.pathSeparator).last.startsWith('style_')) {
          debugPrint(
              '🗑️ [Storage Cleanup] Deleting legacy style: ${file.path}');
          try {
            await file.delete();
          } catch (e) {
            debugPrint('⚠️ Failed to delete ${file.path}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error during storage cleanup: $e');
    }

    // Decodificar bytes
    final bytes = base64Decode(base64String);

    // nombre único
    final fileName = 'style_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final filePath = '${directory.path}/$fileName';

    // Escribir en disco
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    return filePath;
  }

  /// @brief Compiles the technical characteristics of the profile into a detailed generative prompt.
  /// @param brief The user's specific visual brief.
  /// @return A structured string prompt for the DALL-E/Image model.
  String _buildMultimodalPrompt(VisualBrief brief) {
    // Construimos las instrucciones de piel basadas en el análisis técnico
    // Usamos terminología positiva: "Matte finish" o "Dewy finish" en lugar de "No oil".
    String textureInstruction = "Natural skin texture with visible pores.";
    if (brief.skinType == 'Oily') {
      textureInstruction +=
          " finish: Soft matte, velvety texture, control shine but keep dimension.";
    } else if (brief.skinType == 'Dry') {
      textureInstruction += " finish: Hydrated, dewy, luminous skin glow.";
    } else {
      textureInstruction += " finish: Satin, skin-like natural finish.";
    }

    // Estructura siguiendo OpenAI Fundamentals:
    // 1. Scene/Role -> 2. Input/Subject (Invariants) -> 3. Action (The Look) -> 4. Technical Specs -> 5. Constraints
    return '''
ROLE: Expert High-End Beauty Retoucher & Makeup Artist.
TASK: Apply a virtual makeup look to the PROVIDED IMAGE while strictly preserving the subject's identity.

---
1. INPUT SUBJECT ANALYSIS (INVARIANTS - DO NOT CHANGE):
The modification must respect the subject's natural anatomy derived from biometric analysis:
- Face Shape: ${brief.faceShape} (Contour must respect this geometry).
${brief.eyeShape != null ? '- Eye Shape: ${brief.eyeShape} (Eyeliner must adapt to this shape).' : ''}
${brief.skinTone != null ? '- Skin Tone: ${brief.skinTone} (Maintain natural melanin levels).' : ''}
${brief.underTone != null ? '- Undertone: ${brief.underTone} (Ensure makeup colors harmonize with this).' : ''}
- Key Features: ${brief.keyFeatures.join(', ')}.

---
2. THE LOOK (MODIFICATIONS):
GOAL: ${brief.occasion}.
STYLE: ${brief.makeupDirection}.
- Skin Finish: $textureInstruction
- Hair: ${brief.hairDirection}.

---
3. TECHNICAL SPECIFICATIONS (QUALITY CUES):
- Photography Style: Editorial Beauty Portrait.
- Frame: Medium-Close-Up (MCU). Zoom out slightly to ensure the FULL HEAD, HAIR, and NECK are fully visible within the frame. Do not crop the forehead or top of the hair.
- Padding: Leave negative space above the head.
- Camera: 85mm Portrait Lens (flattering compression).
- Aperture: f/2.8 (sharp eyes, soft focus falloff).
- Texture: Ultra-realistic, 8k resolution, subsurface scattering enabled (light penetrating skin).
- Lighting: Softbox studio lighting, flattering catchlights in eyes.

---
4. CONSTRAINTS:
- CHANGE ONLY: The makeup application and hair styling.
- PRESERVE EXACTLY: The subject's bone structure, nose shape, lip shape, and unique identity.
- PRESERVE: The background ambience (unless specified otherwise).
- NEGATIVE CONSTRAINTS: No plastic smoothing, no "AI face" look, no cartoonish exaggeration.
''';
  }
}
