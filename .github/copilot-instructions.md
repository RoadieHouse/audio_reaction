# Project: Sprint React
# Context: Universal AI Agent Instructions

You are assisting an expert developer in building a Flutter application for reactive sprint training. The app delivers unpredictable audio cues (e.g., "Left", "Right") while the user is sprinting. 

These rules apply to ALL agents (UI, Logic, Package Integration, etc.). Read and adhere to the constraints relevant to your current task.

## 1. Critical Domain Constraints (The "Gotchas")
These are non-negotiable requirements for the app's physical use case. Any logic or package recommendation MUST account for these:

- **[CORE-01] Screen-Lock Survival:** The core training sequence (timers, delays, and audio triggers) MUST continue running flawlessly when the device is locked or in the user's pocket. 
  - *Warning:* Standard Dart `Timer`, `Timer.periodic`, or `Future.delayed` will be suspended by the OS. Agents handling sequence logic must use background-safe approaches (e.g., pre-calculating the sequence into an audio playlist with silent gaps, or using proper background execution services).
- **[CORE-02] Audio Ducking/Mixing:** The app's audio cues MUST play *over* or *mix with* the user's active background music (Spotify, Apple Music). It must NEVER pause or stop the user's music. OS-level audio sessions must be configured accordingly.

## 2. Dependency & Package Management
- **[DEP-01] Justify Additions:** Do not hallucinate or arbitrarily add packages to `pubspec.yaml`. If your task requires a new capability (audio, recording, local storage), propose the most lightweight, up-to-date package and wait for approval.
- **[DEP-02] Native First:** Prefer native Dart/Flutter solutions over third-party packages whenever possible.

## 3. Architecture & Code Structure
- **[ARCH-01] Separation of Concerns:** UI components must be completely ignorant of complex business logic, audio initialization, file system operations, and timer calculations. 
- **[ARCH-02] State Management:** Adhere to the project's chosen state management approach (once defined). Keep state classes and UI widgets in separate layers.
- **[ARCH-03] Modular Widgets:** Avoid massive `build` methods. Extract widget trees exceeding 50 lines into private stateless widgets or separate files. Favor `StatelessWidget` unless local UI state strictly requires `StatefulWidget`.

## 4. UI / UX Design System
If you are tasked with generating or modifying UI, strictly adhere to these rules:

- **[UI-01] Dark & High Contrast:** The app is used outdoors in sunlight. Base theme is strict Dark Mode (pure blacks/deep charcoal). Use high-visibility accent colors (e.g., Neon Green, Electric Blue) for active states and primary buttons.
- **[UI-02] Ergonomics:** The app is used during strenuous physical activity. Tap targets must be massive (minimum 48x48 logical pixels, preferably larger for core controls).
- **[UI-03] Glanceability:** Typography for active timers and cues must be huge, bold, and instantly readable (e.g., `TextTheme.displayLarge`). 
- **[UI-04] Minimalism:** Zero clutter. NO heavy drop shadows, NO complex gradients, NO unnecessary borders. Use flat design and negative space (padding) for visual separation.

## 5. Agent Workflow Expectations
- **Step-by-Step:** When given a complex task, output your planned steps before writing the code.
- **Scope Adherence:** Do not modify files outside the scope of your specific prompt (e.g., if asked to build the UI for the Dashboard, do not write the database implementation).
- **Error Handling:** All agents writing platform-channel or hardware-dependent code (audio, microphone, file I/O) must include robust `try/catch` blocks and handle missing permissions gracefully.
