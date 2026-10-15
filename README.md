# ML Lab — native iOS 27 demonstration app

A SwiftUI app with 11 labs for public on-device machine-learning and related perception/compute APIs. Siri and Apple Intelligence integrations are excluded. No third-party dependencies, backend, API keys, or subscription.

**Delivery status:** complete project source and a bundled educational Core ML model. This project has not been compiled, signed, or device-tested: the creation environment has no macOS, Xcode, Swift compiler, or Apple SDK. The newer iOS 27 adapters follow Apple's published documentation and must be checked against your installed SDK. It is not an installable IPA.

## Run on your iPhone

1. On a Mac, install Xcode 27 with the iOS 27 SDK.
2. Open `MLLab.xcodeproj` and choose the **MLLab** scheme.
3. In Signing & Capabilities, select your development team and change `com.example.MLLab` to a unique bundle identifier. Signing credentials are intentionally absent.
4. Connect your iPhone, enable Developer Mode if prompted, select the device, and press Run.
5. Start with Language or the bundled Core ML experiment. For Vision, choose a photo. For audio, record a clip or import an unprotected file. Speech and translation may ask to install language assets.

A physical iPhone is required for meaningful camera, AR, and accelerator checks. Simulator support varies by framework. You cannot compile or install this Xcode project directly from an iPhone using this ZIP alone.

## Included labs

| Lab | Demonstrations | Assets |
|---|---|---|
| Vision | 16 modes: OCR, classification, face landmarks/quality, 2D/3D body pose, hand pose, animals, person/foreground masks, attention/object saliency, rectangles, barcodes, contours, image similarity | System models; chosen photos |
| Language | Detection, hypotheses, entities, parts of speech, lemmas, sentiment, sentence embedding distance, sentence tokens | System models; editable text |
| Translation | English ↔ Spanish | Apple-managed language assets |
| Speech & sound | SpeechAnalyzer/SpeechTranscriber and built-in Sound Analysis classifier | Imported or recorded audio; speech assets |
| Music Understanding | Rhythm, key, loudness, pace, structure, instrument activity; inspect complete JSON output | Unprotected local audio |
| Core ML | Bundled regression, imported model schema/prediction, compute-unit selection | Bundled `TinyRegressor.mlmodel`; optional custom model |
| On-device updates | MLUpdateTask with validated training JSON and exportable updated model | User-supplied updatable model and labeled examples |
| Core AI | Load/specialize/run a stateless single-input Float32 tensor function | User-supplied `.aimodel` |
| GPU compute | MPSGraph dense layer, softmax, synchronized readback, numerical reference check | Fixed illustrative weights |
| AR body tracking | Camera view with tracked 3D joint markers | Supported physical device and camera permission |
| Device & coverage | Hardware/SDK capability checks and scope notes | None |

This is broad framework coverage, not every ML API, request variant, or model architecture. `COVERAGE.md` identifies remaining work. Core AI and on-device updates require additional models; they are not ready-to-run recognition demos without those assets.

## Models and input contracts

The bundled GLM model has one Double input named `x` and one Double output named `y`. Its fixed parameters implement `y = 2x + 0.1`. This tiny model demonstrates actual Core ML inference; it is not a trained real-world predictor and it does not benchmark the Neural Engine.

Core ML import accepts raw `.mlmodel`, `.mlpackage`, or compiled `.mlmodelc` files. The default example JSON is `{"x":2.0}`. Required feature names come from the imported model. Supported inputs: Double, Int64, String, and fixed-shape numeric MultiArray. Outputs include a preview of up to 32 array elements. Image/state/dictionary/sequence and flexible-shape models need a purpose-built input adapter.

Core AI import requires an `.aimodel` prepared with Apple's Core AI tools. Enter its actual function/input/output names, shape, and Float32 values. Default names are examples. No compatible asset is bundled. This adapter handles one stateless Float32 NDArray input and one contiguous Float32 NDArray output. Multi-input/image/stateful models, tokenization, decoding, and generation loops are outside this adapter.

Update Lab requires a model marked updatable by its author. Supply a JSON array with its training feature and label names. The example row is illustrative and does not match an arbitrary model. The app displays the schema and errors. Export the resulting `.mlmodelc` and import it in Core ML to compare predictions. It does not modify your original imported file.

## Measurement and privacy

Processing uses public Apple APIs locally. There are no application-level network calls, telemetry SDKs, accounts, or server uploads. Speech and Translation system assets may download from Apple; Apple may collect framework usage/performance metrics according to its policies. This is not a guarantee that all OS activity is offline.

Vision timing includes decoding/request work; Core ML displays load and prediction timing separately, with compilation outside prediction timing. Core AI timing includes specialization, loading, and inference. Speech includes asset preparation and analysis. GPU includes graph setup, execution, and readback. These measurements are not comparable accelerator benchmarks and do not establish which compute unit actually ran. Use Instruments for CPU/GPU/Neural Engine attribution.

Camera and microphone start only through explicit buttons. Microphone capture stops after 30 seconds, when leaving the screen, or when the app becomes inactive. PhotosPicker exposes only selected images. Imported files are copied into temporary session storage; some are removed on screen exit and all session files are removed at the next app launch. Exported copies remain wherever you save them. Training can continue while navigating away; its temporary output is cleared at the next launch, so export it before closing the app.

## Validation

`python3 Tools/validate_package.py` checks the source/project manifest, permissions, model wire structure and reference arithmetic, asset catalog, and exclusions. These are package checks, not compilation or execution of Apple frameworks.

On macOS run `bash Tools/check_macos.sh` to compile and numerically verify the bundled model with Core ML and build the simulator target. Run the physical-device acceptance checklist in `DEVICE_TESTS.md` after a successful Xcode build.

`Tools/generate_project.py` deterministically regenerates the Xcode project, scheme, Info.plist, and bundled model using Python's standard library. Regenerate after adding Swift source files.
