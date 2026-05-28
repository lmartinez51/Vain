/// @file profile_page.dart
/// @brief UI for collecting user profile data such as photo, skin tone, and makeup preferences.
/// @author Lorenzo Martínez
/// @date 2026-03-30
/// @version 1.0.0
library;

import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:vain_app/features/auth/controllers/auth_controller.dart';
import 'package:vain_app/features/auth/providers/user_provider.dart';
import 'package:vain_app/features/profile/providers/profile_provider.dart';
import 'package:vain_app/features/profile/models/user_profile.dart';

/// @brief A StatefulWidget that presents the onboarding profile completion form.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

/// @brief State class for [ProfilePage], managing the image picker, form state, and persistence flow.
class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

  /// @brief Opens the device gallery to pick an image and updates the profile's photo path.
  /// @param provider The [ProfileProvider] instance.
  /// @return A completed [Future] when the image is picked and path is updated.
  Future<void> _pickImage(ProfileProvider provider) async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked != null && mounted) {
      final userProvider = context.read<UserProvider>();
      final uid = userProvider.currentUser?.uid;
      await provider.setPhotoPath(picked.path, uid: uid);
    }
  }

  /// @brief Validates the profile form, processes facial analysis, and navigates to the mirror screen.
  /// @param provider The [ProfileProvider] instance.
  /// @return A completed [Future] upon successful processing and navigation.
  Future<void> _onContinue(ProfileProvider provider) async {
    if (!provider.isLocalProfileComplete) {
      _showError('Necesitamos tu foto y tu consentimiento para continuar.');
      return;
    }

    try {
      final userProvider = context.read<UserProvider>();
// 🟢 INTENTO 1: Ver en el provider
      String? uid = userProvider.currentUser?.uid;

      // 🟢 INTENTO 2: Si el provider falló, preguntar directo a Firebase
      if (uid == null || uid.isEmpty) {
        uid = FirebaseAuth.instance.currentUser?.uid;
      }

      // Si después de preguntar a Firebase sigue nulo, entonces sí hay un problema de sesión
      if (uid == null || uid.isEmpty) {
        _showError('No se encontró una sesión activa. Reintenta el login.');
        return;
      }
      setState(() => _isSaving = true);

      // 🟢 PASO A: Ejecutar Análisis Facial y Guardado en Firestore
      // Este método ahora hace todo: envía a GPT-5-nano y guarda en Firestore
      await provider.processFaceAnalysis(
        uid: uid,
        userProvider: userProvider,
      );

      // 🟢 PASO B: Marcar Onboarding completo en la cuenta de usuario
      await userProvider.updateUserField(uid, 'isOnboardingComplete', true);

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/mirror');
    } catch (e) {
      debugPrint('❌ Error en el flujo de continuación: $e');
      if (mounted) {
        _showError(
            'Ocurrió un error procesando tu perfil. Revisa tu conexión.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// @brief Displays an error message in a SnackBar.
  /// @param message The error message to show.
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// @brief Builds a generic dropdown widget for selecting enum values.
  /// @param label The label text for the dropdown.
  /// @param value The currently selected enum value.
  /// @param options The list of available enum options.
  /// @param labelBuilder A function converting the enum to a displayable string.
  /// @param onChanged Callback triggered when the value changes.
  /// @return The built dropdown [Widget].
  Widget _buildEnumDropdown<T>({
    required String label,
    required T? value,
    required List<T> options,
    required String Function(T) labelBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            dropdownColor: const Color(0xFF2A1E3F),
            underline: const SizedBox(),
            icon: const Icon(Icons.expand_more, color: Colors.white),
            style: const TextStyle(color: Colors.white),
            items: options
                .map(
                  (o) => DropdownMenuItem(
                    value: o,
                    child: Text(labelBuilder(o)),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  /// @brief Builds the profile onboarding page UI.
  /// @param context The current build context.
  /// @return The built [Widget].
  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.profile;

    return Scaffold(
      backgroundColor: const Color(0xFF1C132B),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Completa tu Perfil',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Para recomendaciones realmente personalizadas',
                style: TextStyle(color: Colors.white60),
              ),

              const SizedBox(height: 32),

              // --- FOTO
              GestureDetector(
                onTap: () => _pickImage(profileProvider),
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.purpleAccent,
                      width: 3,
                    ),
                  ),
                  child: ClipOval(
                    child: profile.photoPath != null
                        ? Image.file(
                            File(profile.photoPath!),
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: Colors.black26,
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white70,
                              size: 40,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              _buildEnumDropdown<SkinTone>(
                label: 'Tono de piel',
                value: profile.skinTone,
                options: SkinTone.values,
                labelBuilder: (v) => v.name,
                onChanged: profileProvider.setSkinTone,
              ),
              const SizedBox(height: 16),

              _buildEnumDropdown<Undertone>(
                label: 'Subtono',
                value: profile.undertone,
                options: Undertone.values,
                labelBuilder: (v) => v.name,
                onChanged: profileProvider.setUndertone,
              ),
              const SizedBox(height: 16),

              _buildEnumDropdown<SkinType>(
                label: 'Tipo de piel',
                value: profile.skinType,
                options: SkinType.values,
                labelBuilder: (v) => v.name,
                onChanged: profileProvider.setSkinType,
              ),
              const SizedBox(height: 16),

              _buildEnumDropdown<MakeupStyle>(
                label: 'Estilo de maquillaje',
                value: profile.makeupStyle,
                options: MakeupStyle.values,
                labelBuilder: (v) => v.name,
                onChanged: profileProvider.setMakeupStyle,
              ),

              const SizedBox(height: 24),

              CheckboxListTile(
                value: profile.consentGiven,
                onChanged: (v) => profileProvider.setConsent(v ?? false),
                activeColor: Colors.purpleAccent,
                checkColor: Colors.black,
                title: const Text(
                  'Autorizo el uso de mi foto y datos para análisis',
                  style: TextStyle(color: Colors.white70),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 24),
              if (!profileProvider.isLocalProfileComplete)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    ' * Por favor, completa todos los campos y sube tu foto',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              // --- BOTÓN CONTINUAR
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      (!_isSaving && profileProvider.isLocalProfileComplete)
                          ? () => _onContinue(profileProvider)
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          'Continuar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // --- BOTÓN CANCELAR (si quieres permitir volver atrás)
              TextButton(
                onPressed: () async {
                  final authController = context.read<AuthController>();
                  await authController.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/login', (_) => false);
                },
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
