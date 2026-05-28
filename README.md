# Vain App 🪞✨

Vain App is an innovative, AI-powered "Magic Mirror" experience built with Flutter. It transforms your device's front-facing camera into an interactive mirror inhabited by an intelligent, real-time AI stylist named Michelle.

## Features 🌟

- **Interactive Magic Mirror**: Uses your device's camera to create a seamless mirror experience with stylized edge vignettes and neon aesthetic overlays.
- **Real-Time AI Voice Conversation**: Integrated with OpenAI's Realtime API, allowing you to have natural, low-latency spoken conversations with Michelle.
- **Dynamic AI Stylist**: Discuss your look and preferences with the AI. Michelle can dynamically analyze your profile and generate tailored makeup and style previews.
- **Animated Ghost/Orb UI**: The interface reacts to the conversation state (Listening, Speaking, Idle) with a draggable, glowing orb and holographic video overlays.
- **Profile Evolution**: The AI can actively suggest and apply updates to your user profile (e.g., preferences, skin tone, favorite styles) based on the context of your spoken conversation.
- **Secure Authentication**: Built with Firebase Authentication (Email/Google Sign-In) and secure local storage.

## Architecture 🏗️

The project is structured entirely around specialized features:
- `lib/features/auth`: Firebase login, secure storage, and user state management.
- `lib/features/mirror`: The core module containing the camera logic, `OpenAIRealtimeClient`, audio routing, and the `MirrorPage` UI.
- `lib/features/profile`: Local and remote state management of the user's preferences and generated traits.
- `lib/features/splash`: App entry point and loading screen.

## Tech Stack & Dependencies 🛠️

- **Framework**: Flutter (Dart)
- **Backend & Auth**: Firebase Core, Firebase Auth, Cloud Firestore, Google Sign In
- **AI & Realtime**: WebSockets, custom `openai_realtime_client`
- **Media**: `camera`, `video_player`, `flutter_sound`, `record`, `audio_session`
- **State Management**: `provider`
- **UI/UX**: `font_awesome_flutter`, `google_fonts`

## Getting Started 🚀

1. **Clone the repository**:
   ```bash
   git clone https://github.com/lmartinez51/Vain.git
   ```
2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```
3. **Setup Environment**:
   Ensure you have your `.env` file populated with the required keys (such as the OpenAI API Key). Note: `.env` is intentionally git-ignored to prevent secret leaks.
4. **Run the App**:
   ```bash
   flutter run
   ```

---
*Vain App - Your reflection, enchanted.*
