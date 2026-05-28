/// @file openai_realtime_client.dart
/// @brief Concrete implementation of a real-time conversation client using OpenAI's WebSocket Realtime API.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vain_app/features/mirror/models/visual_brief.dart';
import 'package:vain_app/features/mirror/services/image_generation_service.dart';
import 'package:web_socket_channel/io.dart';
import 'package:vain_app/features/mirror/services/realtime_conversation_client.dart';
import 'package:vain_app/features/mirror/prompts/prompt_manager.dart';

/// @brief Service managing the WebSocket connection, audio streaming, and function calls with OpenAI Realtime API.
class OpenAIRealtimeClient
    with ChangeNotifier
    implements RealtimeConversationClient {
  /// @brief Initializes a new instance of [OpenAIRealtimeClient].
  OpenAIRealtimeClient();

  // ===============================
  // Config
  // ===============================

  final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  final String _url = 'wss://api.openai.com/v1/realtime?model=gpt-realtime-1.5';

  IOWebSocketChannel? _channel;
  bool _sessionUpdated = false;
  String? _currentInstructions;
  String? _userPhotoPath;

  String? _lastGeneratedImageUrl;
  @override
  String? get lastGeneratedImageUrl => _lastGeneratedImageUrl;

  // ===============================
  // RealtimeConversationClient Callbacks
  // ===============================

  @override
  void Function(Uint8List pcm)? onAssistantAudio;

  @override
  void Function()? onAssistantSpeakingStart;

  @override
  void Function()? onAssistantSpeakingEnd;

  @override
  void Function()? onResponseCreated;

  @override
  void Function(Object error)? onError;

  // ===============================
  // OpenAI Specific Callbacks
  // ===============================

  /// Raw event stream (debug / advanced usage)
  void Function(Map<String, dynamic>)? onEvent;

  /// Transcript generated from model audio
  void Function(String transcript)? onOutputAudioTranscript;

  @override
  void Function()? onUserSpeechStarted;

  @override
  void Function()? onUserSpeechStopped;

  @override
  void Function()? onUserSpeechCommitted;

  @override
  void Function(String transcript)? onUserTranscript;

  @override
  void Function(String transcript)? onAssistantTranscript;

  /// Placeholder for future function-calling handling
  void Function(String name, Map<String, dynamic> arguments)? onFunctionCall;

  @override
  void Function(Map<String, dynamic> profileData)? onUserProfileUpdate;

  @override
  void Function()? onImageGenerationStarted;

  @override
  void Function()? onImageGenerationCompleted;

  // ===============================
  // Tool Definitions
  // ===============================

  Map<String, dynamic> get _updateProfileTool => {
        'type': 'function',
        'name': 'update_user_facial_profile',
        'description':
            'Updates the user\'s facial profile with analyzed data (DNA). Call this IMMEDIATELY after analyzing a user\'s photo to store their technical attributes.',
        'parameters': {
          'type': 'object',
          'required': [
            'face_shape',
            'skin_tone',
            'undertone',
            'skin_type',
            'key_features',
            'makeup_style',
            'eye_shape'
          ],
          'properties': {
            'face_shape': {
              'type': 'string',
              'enum': [
                'oval',
                'round',
                'square',
                'heart',
                'diamond',
                'pear',
                'long'
              ],
              'description': 'The geometric shape of the user\'s face.'
            },
            'skin_tone': {
              'type': 'string',
              'enum': ['fair', 'medium', 'olive', 'deep'],
              'description': 'The overall depth of the user\'s skin color.'
            },
            'undertone': {
              'type': 'string',
              'enum': ['cool', 'neutral', 'warm'],
              'description':
                  'The underlying color beneath the surface of the skin.'
            },
            'skin_type': {
              'type': 'string',
              'enum': ['oily', 'dry', 'combination', 'sensitive', 'normal'],
              'description':
                  'The characteristics of the skin (e.g. shine, texture).'
            },
            'eye_shape': {
              'type': 'string',
              'enum': [
                'almond',
                'hooded',
                'downturned',
                'round',
                'monolid',
                'upturned'
              ],
              'description': 'The shape of the user\'s eyes.'
            },
            'key_features': {
              'type': 'array',
              'items': {'type': 'string'},
              'description':
                  '3-5 distinct facial features identified (e.g. "high cheekbones", "full lips").'
            },
            'makeup_style': {
              'type': 'string',
              'enum': ['natural', 'elegant', 'bold', 'glam'],
              'description': 'Recommended makeup style based on features.'
            }
          }
        }
      };

  Map<String, dynamic> get _imageGenerationTool => {
        'type': 'function',
        'name': 'request_image_generation',
        'description':
            'Request image generation or image editing based on an approved visual brief.',
        'parameters': {
          'type': 'object',
          'required': ['visual_brief', 'user_confirmation'],
          'properties': {
            'user_confirmation': {
              'type': 'boolean',
              'description':
                  'Indicates explicit user consent to generate the image.'
            },
            'visual_brief': {
              'type': 'object',
              'required': [
                'face_shape',
                'key_features',
                'occasion',
                'makeup_direction',
                'hair_direction',
                'style_constraints'
              ],
              'properties': {
                'face_shape': {
                  'type': 'string',
                  'description': 'User face shape as observed from the image.'
                },
                'skin_type': {'type': 'string'},
                'skin_tone': {'type': 'string'},
                'under_tone': {'type': 'string'},
                'eye_shape': {'type': 'string'},
                'key_features': {
                  'type': 'array',
                  'items': {'type': 'string'},
                  'description':
                      'Prominent facial features to emphasize or balance.'
                },
                'occasion': {
                  'type': 'string',
                  'description': 'Event or context the look is designed for.'
                },
                'makeup_direction': {
                  'type': 'string',
                  'description':
                      'Conceptual makeup guidance, colors, intensity, and focus.'
                },
                'hair_direction': {
                  'type': 'string',
                  'description':
                      'Conceptual hairstyle guidance aligned with the occasion.'
                },
                'style_constraints': {
                  'type': 'array',
                  'items': {'type': 'string'},
                  'description':
                      'Constraints such as realism, professionalism, identity preservation.'
                },
                'optional_notes': {
                  'type': 'string',
                  'description':
                      'Additional stylistic or technical notes for the image generator.'
                }
              }
            }
          }
        }
      };

  // ===============================
  // RealtimeConversationClient API
  // ===============================

  @override
  Future<void> startSession({
    String? instructions,
    String? userPhotoPath,
    bool isProfileComplete = true,
  }) async {
    debugPrint('[OpenAIRealtime] Starting session...');
    if (_channel != null) {
      debugPrint('[OpenAIRealtime] Session already active.');
      return;
    }
    _currentInstructions = instructions;
    _userPhotoPath = userPhotoPath;
    debugPrint(
        '[OpenAIRealtime@${shortHash(this)}] _userPhotoPath guardado: $_userPhotoPath');
    await _connect();

    if (_userPhotoPath != null && !isProfileComplete) {
      await _sendUserImage(_userPhotoPath!);
    }
  }

  /// @brief Sends a user image to the AI for hidden internal analysis.
  /// @param path The local path to the image file.
  /// @return A completed [Future] when the image is transmitted.
  Future<void> _sendUserImage(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return;

      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      debugPrint('[OpenAIRealtime] Sending user image for analysis...');
      sendEvent({
        'type': 'conversation.item.create',
        'item': {
          'type': 'message',
          'role': 'user',
          'content': [
            {
              'type': 'input_image',
              'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
            },
            {
              'type': 'input_text',
              'text':
                  'Analiza esta imagen inmediatamente y llama a update_user_facial_profile con los resultados. Hazlo en silencio sin confirmarlo en audio.'
            }
          ]
        }
      });
      // We force a response creation so the model acknowledges the image and calls the tool
      sendEvent({
        'type': 'response.create',
        'response': {
          'modalities': ['audio', 'text'],
        }
      });
    } catch (e) {
      debugPrint('⚠️ [OpenAIRealtime] Error sending image: $e');
    }
  }

  @override
  void sendAudioChunk(Uint8List pcm) {
    if (_channel == null) return;

    final base64Audio = base64Encode(pcm);
    if (pcm.length < 100) {
      debugPrint(
          '[OpenAIRealtime] Sending abnormally small audio chunk: ${pcm.length} bytes');
    }

    sendEvent({
      'type': 'input_audio_buffer.append',
      'audio': base64Audio,
    });
  }

  @override
  Future<void> stopSession() async {
    await _channel?.sink.close();
    _channel = null;
    _sessionUpdated = false;
    _userPhotoPath = null;
    debugPrint('[OpenAIRealtime] Session stopped and state reset');
  }

  @override
  void dispose() {
    stopSession();
    super.dispose();
  }

  // ===============================
  // Connection
  // ===============================

  /// @brief Establishes the WebSocket connection with OpenAI and sets up message listeners.
  /// @return A completed [Future] when connected.
  Future<void> _connect() async {
    try {
      debugPrint('[OpenAIRealtime] Attempting connection...');
      if (_apiKey.isEmpty) {
        debugPrint('[OpenAIRealtime] WARNING: API Key is empty!');
      }

      final socket = await WebSocket.connect(
        _url,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'OpenAI-Beta': 'realtime=v1',
        },
      );

      _channel = IOWebSocketChannel(socket);
      debugPrint('[OpenAIRealtime] Connected to WebSocket');

      _sendSessionUpdateOnce();

      _channel!.stream.listen(
        (msg) {
          _handleMessage(msg);
        },
        onError: (e) {
          debugPrint('[OpenAIRealtime] WebSocket Error: $e');
          onError?.call(e);
        },
        onDone: () {
          debugPrint(
              '[OpenAIRealtime] WebSocket Closed. Code: ${socket.closeCode}, Reason: ${socket.closeReason}');
        },
      );
    } catch (e) {
      debugPrint('[OpenAIRealtime] Connection failed: $e');
      onError?.call(e);
      rethrow;
    }
  }

  // ===============================
  // Message Handling
  // ===============================

  bool _isSpeaking = false;

  /// @brief Parses and routes incoming WebSocket messages to the appropriate handlers.
  /// @param message The raw JSON string message received from the server.
  void _handleMessage(dynamic message) {
    try {
      final Map<String, dynamic> data = json.decode(message);
      if (data['type'] == 'error') {
        debugPrint('[OpenAIRealtime] API Error: ${data['error']}');
      }
      onEvent?.call(data);

      switch (data['type']) {
        case 'response.audio.delta':
          if (!_isSpeaking) {
            _isSpeaking = true;
            onAssistantSpeakingStart?.call();
          }
          _handleAudioDelta(data);
          break;

        case 'response.audio_transcript.done':
          final transcript = data['transcript'];
          if (transcript != null) {
            onAssistantTranscript?.call(transcript);
          }
          break;

        case 'response.done':
          _isSpeaking = false;
          _handleResponseDone(data);
          onAssistantSpeakingEnd?.call();
          break;

        case 'input_audio_buffer.speech_started':
          onUserSpeechStarted?.call();
          break;

        case 'input_audio_buffer.speech_stopped':
          onUserSpeechStopped?.call();
          break;

        case 'input_audio_buffer.committed':
          onUserSpeechCommitted?.call();
          break;

        case 'conversation.item.input_audio_transcription.completed':
          final transcript = data['transcript'];
          if (transcript != null) {
            onUserTranscript?.call(transcript);
          }
          break;

        case 'response.created':
          debugPrint(
              '[OpenAIRealtime] response.created received - Early gating signal');
          onResponseCreated?.call();
          break;

        case 'response.function_call_arguments.done':
          _handleFunctionCallStub(data);
          break;
      }
    } catch (e) {
      debugPrint('[OpenAIRealtime] Invalid message: $e');
    }
  }

  /// @brief Decodes and emits Delta PCM audio from the assistant.
  /// @param data The JSON message containing the base64 audio delta.
  void _handleAudioDelta(Map<String, dynamic> data) {
    try {
      final decoded = base64Decode(data['delta']);
      onAssistantAudio?.call(decoded);
    } catch (e) {
      debugPrint('[Realtime] Audio decode error: $e');
    }
  }

  /// @brief Processes the completion of an AI response to extract final transcripts.
  /// @param data The JSON message indicating response completion.
  void _handleResponseDone(Map<String, dynamic> data) {
    try {
      final output = data['response']?['output'];
      if (output is List && output.isNotEmpty) {
        final content = output.first['content'];
        if (content is List) {
          final audioItem = content.firstWhere(
            (e) => e['type'] == 'audio',
            orElse: () => null,
          );

          final transcript = audioItem?['transcript'];
          if (transcript != null) {
            onOutputAudioTranscript?.call(transcript);
          }
        }
      }
    } catch (e) {
      debugPrint('[Realtime] response.done parse error: $e');
    }
  }

  // ===============================
  // Function Calling
  // ===============================

  /// @brief Handles the execution of the image generation tool call requested by the AI.
  /// @param callId The unique identifier of the tool call.
  /// @param arguments The parsed JSON arguments provided by the AI.
  /// @return A completed [Future] when the image is generated and the result is returned to the AI.
  Future<void> _handleImageGeneration(
      String callId, Map<String, dynamic> arguments) async {
    try {
      final bool userConfirmed = arguments['user_confirmation'] == true;

      if (!userConfirmed) {
        sendEvent({
          "type": "conversation.item.create",
          "item": {
            "type": "function_call_output",
            "call_id": callId,
            "output": "User cancelled image generation.",
          }
        });

        sendEvent({
          "type": "response.create",
          "response": {
            "modalities": ["audio", "text"],
            "instructions": PromptManager.conversationalResponse(
                'Respeta la decisión del usuario y dile que puedes ajustar el look si lo desea.'),
          }
        });
        return;
      }

      final VisualBrief visualBrief =
          VisualBrief.fromJson(arguments['visual_brief']);

      visualBrief.validate();

      // UI: Notify that generation has started (Mutes mic, shows loading)
      onImageGenerationStarted?.call();

      final String imageUrl = await generateStylePreview(
            visualBrief: visualBrief,
            userConfirmed: true,
          ) ??
          '';

      if (imageUrl.isEmpty) {
        throw Exception('Resultado vacío');
      }

      _lastGeneratedImageUrl = imageUrl;

      // UI: Notify that generation has finished BEFORE triggering the AI response
      onImageGenerationCompleted?.call();
      notifyListeners();

      sendEvent({
        "type": "conversation.item.create",
        "item": {
          "type": "function_call_output",
          "call_id": callId,
          "output": json.encode({"image_url": imageUrl}),
        }
      });

      sendEvent({
        "type": "response.create",
        "response": {
          "modalities": ["audio", "text"],
          "instructions": PromptManager.functionResultResponse(
              'El look está listo. ¡Míralo en pantalla!'),
        }
      });
    } catch (e) {
      debugPrint('[Realtime] Error en image generation: $e');

      // Recover UI state if generation fails
      onImageGenerationCompleted?.call();

      sendEvent({
        "type": "conversation.item.create",
        "item": {
          "type": "function_call_output",
          "call_id": callId,
          "output": "Error: $e",
        }
      });

      sendEvent({
        "type": "response.create",
        "response": {
          "modalities": ["audio", "text"],
          "instructions": PromptManager.imageGenerationFailureResponse(
              'Hubo un error al generar la imagen: $e'),
        }
      });
    }
  }

  /// @brief Executes the profile update tool call based on AI analysis.
  /// @param callId The unique identifier of the tool call.
  /// @param arguments The parsed facial characteristic arguments.
  /// @return A completed [Future] when the profile update is dispatched.
  Future<void> _handleUpdateProfile(
      String callId, Map<String, dynamic> arguments) async {
    debugPrint('[Realtime] Updating user profile with: $arguments');

    try {
      onUserProfileUpdate?.call(arguments);

      sendEvent({
        "type": "conversation.item.create",
        "item": {
          "type": "function_call_output",
          "call_id": callId,
          "output":
              json.encode({"status": "success", "message": "Profile updated."}),
        }
      });

      sendEvent({
        "type": "response.create",
        "response": {
          "modalities": ["audio", "text"],
        }
      });
    } catch (e) {
      debugPrint('Error updating profile from AI: $e');
      sendEvent({
        "type": "conversation.item.create",
        "item": {
          "type": "function_call_output",
          "call_id": callId,
          "output": "Error updating profile: $e",
        }
      });
      // Always create a response even on error
      sendEvent({
        "type": "response.create",
        "response": {
          "modalities": ["audio", "text"],
        }
      });
    }
  }

  /// @brief Routes incoming function calls to their respective handlers.
  /// @param data The JSON message containing the function call details.
  /// @return A completed [Future] when the routing finishes.
  Future<void> _handleFunctionCallStub(Map<String, dynamic> data) async {
    try {
      final functionName = data['name'];
      final callId = data['call_id'];
      debugPrint(
          '[Realtime] Function call requested: $functionName (ID: $callId)');

      final Map<String, dynamic> arguments =
          json.decode(data['arguments'] ?? '{}');

      switch (functionName) {
        case 'request_image_generation':
          if (callId != null) {
            await _handleImageGeneration(callId, arguments);
            break;
          }
          break;

        case 'update_user_facial_profile':
          if (callId != null) {
            await _handleUpdateProfile(callId, arguments);
            break;
          }
          break;

        default:
          debugPrint('[Realtime] Función no reconocida: $functionName');
          // Forzar respuesta conversacional si la función no existe, para no bloquear el turno
          sendEvent({
            "type": "response.create",
            "response": {
              "modalities": ["audio", "text"],
              "instructions": PromptManager.conversationalResponse(
                  'No pude ejecutar esa función, pero sigue la conversación.'),
            }
          });
      }
    } catch (e, stackTrace) {
      debugPrint('[Realtime] Error en function dispatcher: $e');
      debugPrint(stackTrace.toString());
    }
  }

  // ===============================
  // Session
  // ===============================

  /// @brief Sends the initial session configuration including tools and voice settings to OpenAI.
  void _sendSessionUpdateOnce() {
    if (_sessionUpdated) return;
    debugPrint('[OpenAIRealtime] Sending session.update...');
    _sessionUpdated = true;

    final finalInstructions =
        _currentInstructions ?? PromptManager.sessionInitPromptEmpty();

    sendEvent({
      'type': 'session.update',
      'session': {
        'modalities': ['audio', 'text'],
        'instructions': finalInstructions,
        'voice': 'coral',
        'input_audio_format': 'pcm16',
        'output_audio_format': 'pcm16',
        'input_audio_transcription': {
          'model': 'whisper-1',
        },
        'turn_detection': {
          'type': 'server_vad',
          'threshold': 0.6,
          'prefix_padding_ms': 300,
          'silence_duration_ms': 600,
        },
        'tool_choice': 'auto',
        'tools': [
          _imageGenerationTool,
          _updateProfileTool,
        ],
      }
    });
  }

  // ===============================
  // Public API
  // ===============================

  /// @brief Sends a JSON-encoded event to the active WebSocket channel.
  /// @param event The structured event data to send.
  void sendEvent(Map<String, dynamic> event) {
    if (_channel == null) return;
    _channel!.sink.add(json.encode(event));
  }

  // ===============================
  // Image Generation
  // ===============================

  /// @brief Orchestrates the DALL-E image generation using the analyzed visual brief.
  /// @param visualBrief The parsed instructions for the generative model.
  /// @param userConfirmed A boolean indicating explicit user consent.
  /// @return A completed [Future] containing the generated image URL, or null if cancelled.
  Future<String?> generateStylePreview({
    required VisualBrief visualBrief,
    required bool userConfirmed,
  }) async {
    debugPrint('🧠 [generateStylePreview] Inicio');

    if (!userConfirmed) {
      debugPrint(
        '⚠️ [generateStylePreview] Generación cancelada: sin confirmación',
      );
      return null;
    }

    try {
      visualBrief.validate();
    } catch (e) {
      debugPrint(
        '❌ [generateStylePreview] VisualBrief inválido: ${e.toString()}',
      );
      throw Exception('VisualBrief inválido');
    }

    final ImageGenerationService imageService;
    try {
      imageService = ImageGenerationService();
    } catch (e) {
      debugPrint(
        '❌ [generateStylePreview] Error inicializando ImageGenerationService: $e',
      );
      throw Exception('No se pudo inicializar el servicio de imágenes');
    }

    try {
      debugPrint(
          '[OpenAIRealtime@${shortHash(this)}] Usando path: $_userPhotoPath');
      if (_userPhotoPath == null || _userPhotoPath!.isEmpty) {
        throw Exception(
            'No se encontró la foto del usuario para la generación');
      }

      final file = File(_userPhotoPath!);
      if (!await file.exists()) {
        throw Exception('Physical photo file missing at path: $_userPhotoPath');
      }

      final imageUrl = await imageService.generateImage(
        brief: visualBrief,
        userPhotoPath: _userPhotoPath!,
      );

      if (imageUrl.isEmpty) {
        debugPrint(
          '❌ [generateStylePreview] Imagen generada inválida (URL vacía)',
        );
        throw Exception('Resultado de imagen inválido');
      }

      debugPrint(
        '✅ [generateStylePreview] Imagen generada correctamente',
      );
      return imageUrl;
    } catch (e, stackTrace) {
      debugPrint(
        '🔥 [generateStylePreview] Error durante la generación de imagen: $e',
      );
      debugPrint(stackTrace.toString());

      throw Exception(
        'Error al generar la vista previa del estilo',
      );
    }
  }
}
