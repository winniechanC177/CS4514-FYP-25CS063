-keep class ai.onnxruntime.** { *; }

# ── MediaPipe (flutter_gemma transitive dependency) ───────────────────────────
# Proto classes referenced by MediaPipe's GraphProfiler / Graph are not
# shipped in the AAR, so R8 cannot resolve them during minification.
# Suppress the missing-class errors; these code paths are never called at runtime.
-dontwarn com.google.mediapipe.**
-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate

