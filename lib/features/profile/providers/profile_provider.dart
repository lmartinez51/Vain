/// @file profile_provider.dart
/// @brief State management for the user's profile, handling local storage and cloud synchronization.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:vain_app/features/profile/models/user_profile.dart';
import 'package:vain_app/features/auth/services/secure_storage_service.dart';
import 'package:vain_app/features/auth/providers/user_provider.dart';
import 'package:vain_app/features/profile/services/face_analysis_service.dart';

/// @brief Provider class managing user profile state, including facial analysis and persistent storage.
class ProfileProvider extends ChangeNotifier {
  final SecureStorageService _storageService;
  final FaceAnalysisService _analysisService;

  // Añadimos un estado de carga para el análisis
  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;

  bool _isHydrated = false;
  bool get isHydrated => _isHydrated;

  UserProfile _profile = const UserProfile();

  /// @brief Initializes a new instance of [ProfileProvider].
  /// @param _storageService The local secure storage service.
  /// @param _analysisService The face analysis service.
  ProfileProvider(this._storageService, this._analysisService);

  UserProfile get profile => _profile;

  /// @brief Defines if the profile is complete based on local data. Used during onboarding.
  /// @return A boolean indicating if the local profile is complete.
  bool get isLocalProfileComplete => _profile.isComplete;

  /// @brief Triggers facial analysis and synchronizes with the hybrid profile.
  /// @param uid The user's unique identifier.
  /// @param userProvider The provider managing the user's synchronization.
  /// @return A completed [Future] when the process finishes.
  Future<void> processFaceAnalysis({
    required String uid,
    required UserProvider userProvider,
  }) async {
    if (_profile.photoPath == null) return;

    _isAnalyzing = true;
    notifyListeners();

    try {
      // 1. Intentar el análisis con la IA
      final results = await _analysisService.analyzeFace(_profile.photoPath!);

      final String? incomingFaceShape =
          results['faceShape']?.toString().trim().toLowerCase();

      _profile = _profile.copyWith(
        faceShape: _parseEnum(FaceShape.values, incomingFaceShape),
        keyFeatures: List<String>.from(results['keyFeatures'] ?? []),
      );

      debugPrint("🧬 ADN Facial obtenido con éxito");

      // 🟢 PUNTO CLAVE 1: Notificamos que el objeto _profile ya tiene el ADN
      // antes de empezar la sincronización con la nube (que puede tardar)
      notifyListeners();
    } catch (e) {
      debugPrint("⚠️ Error IA (ADN no obtenido): $e");
    } finally {
      // 2. Persistencia Híbrida
      await saveProfileHybrid(uid: uid, userProvider: userProvider);

      _isAnalyzing = false;

      // 🟢 PUNTO CLAVE 2: Notificación final (apaga el spinner de carga)
      notifyListeners();
    }
  }

  /// @brief Updates the user's photo path and triggers facial analysis.
  /// @param path The local path to the new photo.
  /// @param uid The user's unique identifier.
  /// @param userProvider The provider managing user synchronization.
  /// @return A completed [Future] when the update and analysis finish.
  Future<void> updatePhotoAndAnalyze(
      String path, String uid, UserProvider userProvider) async {
    await setPhotoPath(path, uid: uid);
    await processFaceAnalysis(uid: uid, userProvider: userProvider);
  }

  /// @brief Saves the user profile locally and synchronizes it to Firestore if possible.
  /// @param uid The user's unique identifier.
  /// @param userProvider The provider managing cloud synchronization.
  /// @return A completed [Future] when persistence is done.
  Future<void> saveProfileHybrid({
    required String uid,
    required UserProvider userProvider,
  }) async {
    try {
      // 1. Local
      await _storageService.saveUserProfile(_profile);

      // 2. Sync a Firestore (Blindado con todos los campos)
      final preferences = {
        'skinTone': _profile.skinTone?.name,
        'undertone': _profile.undertone?.name,
        'skinType': _profile.skinType?.name,
        'makeupStyle': _profile.makeupStyle?.name,
        'consentGiven': _profile.consentGiven,
        // 🟢 NUEVOS CAMPOS ADN (Faltaban aquí)
        'faceShape': _profile.faceShape?.name,
        'eyeShape': _profile.eyeShape?.name,
        'keyFeatures': _profile.keyFeatures,
        'photoPath': _profile.photoPath, // Persistimos la ruta (local o flag)
      };
      debugPrint('🚀 ENVIANDO A FIRESTORE: $preferences');
      debugPrint('UID: $uid');
      await userProvider.syncProfilePreferences(uid, preferences);
      debugPrint(
          '✅ [ProfileProvider] Perfil sincronizado íntegramente en la nube');
    } catch (e) {
      debugPrint('❌ [ProfileProvider] Error en saveProfileHybrid: $e');
    }
  }

  /// @brief Reconciles local profile data with data fetched from the cloud.
  /// @param remotePrefs The remote preferences map to apply.
  void updateFromRemote(Map<String, dynamic> remotePrefs) {
    _profile = _profile.copyWith(
      skinTone: _parseEnum(SkinTone.values, remotePrefs['skinTone']),
      undertone: _parseEnum(Undertone.values, remotePrefs['undertone']),
      skinType: _parseEnum(SkinType.values, remotePrefs['skinType']),
      makeupStyle: _parseEnum(MakeupStyle.values, remotePrefs['makeupStyle']),
      consentGiven: remotePrefs['consentGiven'] ?? false,
      faceShape: _parseEnum(FaceShape.values, remotePrefs['faceShape']),
      eyeShape: _parseEnum(EyeShape.values, remotePrefs['eyeShape']),
      keyFeatures: remotePrefs['keyFeatures'] != null
          ? List<String>.from(remotePrefs['keyFeatures'])
          : [],
      // photoPath se mantiene como esté localmente (null si es dispositivo nuevo)
    );
    notifyListeners();
    // Persistimos localmente los datos recuperados
    _storageService.saveUserProfile(_profile);
  }

  /// @brief Private helper to safely parse enums case-insensitively.
  /// @param values The list of enum values to match against.
  /// @param name The string representation to find.
  /// @return The matched enum value, or null if not found.
  T? _parseEnum<T extends Enum>(List<T> values, String? name) {
    if (name == null || name.trim().isEmpty) return null;

    final cleanName = name.trim().toLowerCase();
    try {
      // Busca ignorando mayúsculas/minúsculas en lugar de un match estricto
      return values.firstWhere((e) => e.name.toLowerCase() == cleanName);
    } catch (_) {
      debugPrint(
          '⚠️ [ProfileProvider] Enum parse falló para el valor: "$name"');
      return null;
    }
  }

  /// @brief Loads the profile from local secure storage.
  /// @param force If true, forcefully reloads even if already hydrated.
  /// @return A completed [Future] when loading is done.
  Future<void> loadProfile({bool force = false}) async {
    if (_isHydrated && !force) return;

    final loaded = await _storageService.readUserProfile();
    debugPrint(
        '📂 [ProfileProvider] Cargando perfil local. ¿Tiene foto?: ${loaded?.photoPath != null}');
    if (loaded != null) {
      _profile = loaded;
      debugPrint('📂 [ProfileProvider] Path cargado: ${_profile.photoPath}');
      _isHydrated = true;
      notifyListeners();
    }
  }

  /// @brief Hydration bridge to update profile state from external data (e.g. AI or Auth).
  /// @param preferences The dynamic preferences data (Map or Object).
  /// @param uid Optional user ID for cloud sync.
  /// @param userProvider Optional user provider for cloud sync.
  /// @return A completed [Future] when the state is updated.
  Future<void> updateFromPreferences(
    dynamic preferences, {
    String? uid,
    UserProvider? userProvider,
  }) async {
    if (preferences == null) return;

    // Aceptamos tanto ProfilePreferences (objeto) como Map
    // Esto da flexibilidad por si viene directo del JSON o del modelo
    String? newPhotoPath;
    String? newSkinTone;
    String? newUndertone;
    String? newSkinType;
    String? newMakeupStyle;
    String? newFaceShape;
    String? newEyeShape;
    List<String> newKeyFeatures = [];
    bool? newConsent;

    // Si es un objeto de modelo (UserProvider ya lo tiene parseado)
    if (preferences is! Map) {
      // Asumimos que es ProfilePreferences
      try {
        newPhotoPath = preferences.photoPath;
        newSkinTone = preferences.skinTone;
        newUndertone = preferences.undertone;
        newSkinType = preferences.skinType;
        newMakeupStyle = preferences.makeupStyle;
        newFaceShape = preferences.faceShape;
        newEyeShape = preferences.eyeShape;
        newKeyFeatures = preferences.keyFeatures ?? [];
        newConsent = preferences.consentGiven;
      } catch (e) {
        debugPrint(
            '⚠️ [ProfileProvider] Error leyendo objeto ProfilePreferences: $e');
      }
    } else {
      // Si es un Map (ej. desde AI crudo o JSON)
      try {
        // MApeamos de snake_case (AI) a camelCase (ProfilePreferences / Firestore)
        final Map<String, dynamic> mappedPrefs = {
          'photoPath': preferences['photoPath'],
          'skinTone': preferences['skin_tone'] ?? preferences['skinTone'],
          'undertone': preferences['under_tone'] ?? preferences['undertone'],
          'skinType': preferences['skin_type'] ?? preferences['skinType'],
          'makeupStyle':
              preferences['makeup_style'] ?? preferences['makeupStyle'],
          'faceShape': preferences['face_shape'] ?? preferences['faceShape'],
          'eyeShape': preferences['eye_shape'] ?? preferences['eyeShape'],
          'consentGiven': preferences['consentGiven'],
        };

        final kf = preferences['key_features'] ?? preferences['keyFeatures'];
        if (kf is List) {
          mappedPrefs['keyFeatures'] = List<String>.from(kf);
        }

        newPhotoPath = mappedPrefs['photoPath'];
        newSkinTone = mappedPrefs['skinTone'];
        newUndertone = mappedPrefs['undertone'];
        newSkinType = mappedPrefs['skinType'];
        newMakeupStyle = mappedPrefs['makeupStyle'];
        newFaceShape = mappedPrefs['faceShape'];
        newEyeShape = mappedPrefs['eyeShape'];
        newKeyFeatures = mappedPrefs['keyFeatures'] ?? [];
        newConsent = mappedPrefs['consentGiven'];
      } catch (e) {
        debugPrint('⚠️ [ProfileProvider] Error leyendo Map preferences: $e');
      }
    }

    // 1. Guardamos una "fotografía" del estado actual ANTES de cambiar nada
    final oldProfile = _profile;

    // 2. Actualizamos el estado en memoria (permitimos updates parciales)
    // Si algún valor es null, mantenemos el actual (por el copyWith, pero necesitamos pasar el nuevo valor O el viejo)
    // En este caso de uso (AI update), solo queremos enriquecer.

    _profile = _profile.copyWith(
      photoPath: newPhotoPath ?? _profile.photoPath,
      skinTone: _parseEnum(SkinTone.values, newSkinTone) ?? _profile.skinTone,
      undertone:
          _parseEnum(Undertone.values, newUndertone) ?? _profile.undertone,
      skinType: _parseEnum(SkinType.values, newSkinType) ?? _profile.skinType,
      makeupStyle: _parseEnum(MakeupStyle.values, newMakeupStyle) ??
          _profile.makeupStyle,
      consentGiven: newConsent ?? _profile.consentGiven,
      faceShape:
          _parseEnum(FaceShape.values, newFaceShape) ?? _profile.faceShape,
      eyeShape: _parseEnum(EyeShape.values, newEyeShape) ?? _profile.eyeShape,
      keyFeatures:
          newKeyFeatures.isNotEmpty ? newKeyFeatures : _profile.keyFeatures,
    );

    // 3. Comparamos si la IA realmente cambió algo
    // Asume que UserProfile usa Equatable o tiene el operador == sobreescrito.
    final bool hasChanges = oldProfile != _profile;

    if (!hasChanges) {
      debugPrint(
          '🛑 [ProfileProvider] Sin cambios detectados. Omitiendo escritura local y en Firestore para ahorrar recursos.');
      _isHydrated = true;
      return; // Cortamos la ejecución aquí
    }

    // 4. ⚡ ACTUALIZACIÓN "TRICKLE DOWN": Persistimos inmediatamente en local
    await _storageService.saveUserProfile(_profile);

    _isHydrated = true;
    notifyListeners();

    debugPrint(
        '🌉 [ProfileProvider] Perfil actualizado (AI/Nube) y guardado en Local.');

    // 5. ☁️ Sincronización a Firestore (Solo lo necesario)
    if (uid != null && userProvider != null) {
      debugPrint(
          '🚀 [ProfileProvider] Cambios biométricos detectados. Subiendo a Firestore para UID: $uid');
      await saveProfileHybrid(uid: uid, userProvider: userProvider);
    }
  }

  /// @brief Sets the skin tone of the user profile.
  /// @param value The selected [SkinTone].
  void setSkinTone(SkinTone? value) {
    _profile = _profile.copyWith(skinTone: value);
    notifyListeners();
  }

  /// @brief Sets the undertone of the user profile.
  /// @param value The selected [Undertone].
  void setUndertone(Undertone? value) {
    _profile = _profile.copyWith(undertone: value);
    notifyListeners();
  }

  /// @brief Sets the skin type of the user profile.
  /// @param value The selected [SkinType].
  void setSkinType(SkinType? value) {
    _profile = _profile.copyWith(skinType: value);
    notifyListeners();
  }

  /// @brief Sets the makeup style preference of the user profile.
  /// @param value The selected [MakeupStyle].
  void setMakeupStyle(MakeupStyle? value) {
    _profile = _profile.copyWith(makeupStyle: value);
    notifyListeners();
  }

  /// @brief Sets the local photo path for the profile, managing old files if a uid is present.
  /// @param sourcePath The raw source path of the new photo.
  /// @param uid Optional user ID.
  /// @return A completed [Future] when the path is persisted.
  Future<void> setPhotoPath(String? sourcePath, {String? uid}) async {
    if (sourcePath == null) {
      _profile = _profile.copyWith(photoPath: null);
      notifyListeners();
      await _storageService.saveUserProfile(_profile);
      return;
    }

    String finalPath = sourcePath;

    if (uid != null) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'profile_photo_${uid}_$timestamp.jpg';
        final permanentPath = p.join(directory.path, fileName);

        // 1. Limpieza del archivo anterior si existe y está en Documentos
        if (_profile.photoPath != null) {
          final oldFile = File(_profile.photoPath!);
          if (await oldFile.exists() && oldFile.path.contains(directory.path)) {
            await oldFile.delete();
            debugPrint(
                '🗑️ [ProfileProvider] Foto antigua eliminada: ${_profile.photoPath}');
          }
        }

        // 2. Mover/Copiar el nuevo archivo
        final sourceFile = File(sourcePath);
        if (await sourceFile.exists()) {
          // Usamos copy en lugar de rename para mayor seguridad entre particiones
          await sourceFile.copy(permanentPath);
          finalPath = permanentPath;
          debugPrint(
              '📂 [ProfileProvider] Foto migrada a documentos: $finalPath');
        }
      } catch (e) {
        debugPrint('⚠️ [ProfileProvider] Error migrando foto: $e');
      }
    }

    _profile = _profile.copyWith(photoPath: finalPath);
    notifyListeners();
    // Guardamos inmediatamente para que, pase lo que pase con la IA,
    // la ruta de la foto ya esté segura en el almacenamiento local.
    await _storageService.saveUserProfile(_profile);
    _isHydrated = true; // Si lo acabamos de setear, estamos hidratados
    debugPrint('💾 [ProfileProvider] PhotoPath persistido: $finalPath');
  }

  /// @brief Sets the consent flag for the user's data.
  /// @param value True if consent is granted, false otherwise.
  void setConsent(bool value) {
    _profile = _profile.copyWith(consentGiven: value);
    notifyListeners();
  }

  /// @brief Saves the current profile to local secure storage.
  /// @return A completed [Future] when the save is complete.
  Future<void> saveProfile() async {
    await _storageService.saveUserProfile(_profile);
  }

  /// @brief Clears the current profile from memory and local storage.
  /// @return A completed [Future] when the profile is cleared.
  Future<void> clearProfile() async {
    _profile = const UserProfile();
    await _storageService.deleteUserProfile();
    notifyListeners();
  }
}
