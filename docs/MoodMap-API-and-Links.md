# Mood Map Design and API

## Overview

Mood Map is triggered from within a reading session. Once a reading session is active, the user can start a mood session — the camera captures frames, Vision detects facial expressions, and on stop the result is aggregated into one of three outcomes: **Focused / Inspired / Tired**.

---

## Emotion Detection

Uses **Apple Vision** on-device (`VNDetectFaceRectanglesRequest`). Currently simplified to detect face presence and return `"neutral"` → maps to **Focused**. Full emotion recognition (`VNRecognizeEmotionsRequest`, iOS 17+) is a future TODO.

| Item | Detail |
|------|--------|
| Current API | `VNDetectFaceRectanglesRequest` |
| Target API | `VNRecognizeEmotionsRequest` (iOS 17+) |
| Input | `CVPixelBuffer` from `AVCaptureSession`, sampled every 2s |
| Vision docs | https://developer.apple.com/documentation/vision |

---

## Code Locations

| File | Responsibility |
|------|---------------|
| `Models/MoodMapModels.swift` | `QuickMood`, `MoodSample`, `MoodMapSession`, emotion mapping + aggregation |
| `Stores/MoodSessionStore.swift` | Mood session state, sample collection, persistence (`UserDefaults`) |
| `Services/MoodMapCaptureService.swift` | Camera (`AVCaptureSession`) + Vision, throttled sampling |
| `Views/MoodMapCameraView.swift` | Full-screen camera UI, "Stop Mood Map" button |

---

## Data Flow

1. User starts a reading session → "mood session" button becomes available
2. User taps "mood session" → `MoodSessionStore.startMoodMap()` → full-screen camera opens
3. `MoodMapCaptureService` samples frames every ~2s → `appendCvSample(_:)` per result
4. User taps "Stop Mood Map" → `MoodSessionStore.endMoodMap()` → `aggregateSamplesToQuickMood(currentCvSamples)` → result saved
5. Sheet shows **Focused / Inspired / Tired** (read-only) → user taps OK → `clearLastRecognizedMood()`

---

*Last Updated: March 2026*
