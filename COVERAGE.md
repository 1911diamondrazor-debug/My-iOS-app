# Public API coverage and boundaries

The app targets iOS 27. No finite app can exercise every combination of Apple's ML APIs, every model architecture, every compute backend, and every hardware-dependent perception feature. This inventory describes the delivered source honestly; all native runtime paths await Xcode/device verification.

| Framework / area | Implemented source paths | Remaining extensions |
|---|---|---|
| Core ML | Compile/load; model description; typed feature provider; prediction; compute-unit policy | Image inputs, model state/KV cache, async/batch prediction, multifunction models, compute-plan/device instrumentation, custom layers |
| Core ML updates | MLUpdateTask, labeled batch provider, feature validation, metrics, updated model export | Bundled updatable trained asset, live progress UI, cancellation controls, held-out accuracy evaluation |
| Core AI (27) | AIModel specialization; function lookup; descriptor validation; NDArray; inference/output extraction | Bundled `.aimodel`, images, multi-input/stateful inference, cache/specialization controls, language-model tokenization/generation |
| Vision | Sixteen independent image experiment modes | Live camera Vision, object tracking across video, optical flow, trajectories, animal pose, document structure, cross-image registration, custom VNCoreML models and additional request variants |
| Natural Language | Recognition/hypotheses, tokenization, lexical/lemma/entity tags, sentiment, sentence cosine distance | Custom NLModel, word embedding neighbors, contextual embeddings, language-specific evaluation |
| Speech | SpeechAnalyzer, SpeechTranscriber, assets, prerecorded/recorded file input and result collection | Streaming live transcription, SpeechDetector VAD, DictationTranscriber fallback, transcription attributes and timestamps |
| Translation | SwiftUI TranslationSession lifecycle, asset preparation, en/es translation | Dynamic language picker, batches, attributed text, support-status dashboard |
| Sound Analysis | Built-in SNClassifySoundRequest through SNAudioFileAnalyzer | Live stream classification, custom sound model, visualization of window-level events |
| Music Understanding (27) | All six session analyses; JSON result exploration | Timeline/player synchronization, interactive result charts, streaming provider |
| ARKit perception | Live supported-device body skeleton in ARSCNView | Face tracking, scene depth, LiDAR reconstruction, hand/object tracking where publicly available |
| Metal Performance Shaders Graph | Dense tensor multiplication, softmax, explicit Metal queue, readback and reference check | Gradients/backpropagation, mixed precision, graph serialization, Metal tensor/custom operation paths |
| Accelerate / BNNS | Not implemented | Vector/DSP baselines, BNNSGraph execution/training where supported |
| Create ML Components | Not implemented | Applicable runtime transform/training pipelines and compatible component assets |
| Create ML | Authoring is outside the iPhone app | Build/train model assets on macOS and import into the app |
| VisionKit | Not implemented | DataScanner, interactive image analysis and Live Text UI |
| SensitiveContentAnalysis | Not implemented | Consent-based sensitive-content checking and system policy handling |
| Additional domain frameworks | Not implemented | ShazamKit, Core Motion activity recognition, and other domain-specific systems; not all are general-purpose ML APIs |

Excluded: Siri, App Intents integration, Foundation Models, Apple Intelligence, Writing Tools, Image Playground, and Private Cloud Compute.

## Primary references checked during creation

- https://developer.apple.com/ios/whats-new/
- https://developer.apple.com/documentation/coreai
- https://developer.apple.com/documentation/coreai/integrating-on-device-ai-models-in-your-app-with-core-ai
- https://developer.apple.com/documentation/musicunderstanding
- https://developer.apple.com/documentation/musicunderstanding/musicunderstandingsession
- https://developer.apple.com/documentation/musicunderstanding/musicunderstandingsession/sessionresult
- https://developer.apple.com/documentation/speech/speechanalyzer
- https://developer.apple.com/documentation/speech/speechanalyzer/analyzesequence(from:)
- https://developer.apple.com/documentation/speech/speechanalyzer/cancelandfinishnow()
- https://developer.apple.com/documentation/speech/speechtranscriber
- https://developer.apple.com/documentation/translation/translationsession
- https://developer.apple.com/documentation/coreml/mlupdatetask
- https://developer.apple.com/documentation/coreml/mlupdatecontext
- https://developer.apple.com/documentation/metalperformanceshadersgraph/mpsgraph
- https://developer.apple.com/documentation/arkit/arskeleton
- https://apple.github.io/coremltools/mlmodel/Format/Model.html
- https://apple.github.io/coremltools/mlmodel/Format/FeatureTypes.html
- https://apple.github.io/coremltools/mlmodel/Format/GLMRegressor.html

Some new-framework documentation was marked beta when retrieved. Match it to the installed iOS 27 SDK and adjust signatures if necessary before claiming build validation.
