# Physical-device acceptance checklist — not yet executed

Use an iOS 27 iPhone and Xcode 27. A checkmark here should only be added after observing the actual result.

- [ ] Build Debug and Release in Xcode; no unresolved API signatures. Launch portrait and landscape on iPhone/iPad; check large Dynamic Type.
- [ ] Launch without Apple Intelligence enabled; built-in labs remain usable without Siri or Foundation Models.
- [ ] Core ML bundled model: x=2 yields y=4.1; x=0 yields 0.1; negative x works. Compare CPU-only and automatic results, not claimed accelerator use.
- [ ] Core ML imports: missing feature, malformed JSON, wrong shape/type, and unsupported feature input return descriptive errors. Valid compatible model returns real output.
- [ ] Vision: select a rotated photo; boxes match displayed orientation. Read printed en/es text, scan a QR code, classify a scene, find face/hand/body landmarks, inspect masks/saliency, compare the same image to itself (near-zero distance).
- [ ] Vision: blank image produces no-result feedback. 3D body pose unsupported/failed inference returns framework error without crashing.
- [ ] Language: English/Spanish detection, names and sentiment; unsupported embedding language reports availability. Empty input cannot run.
- [ ] Translation: approve initial asset download, translate both directions, edit and rerun same direction. Deny/cancel download and verify clear error/no stuck loading state.
- [ ] Microphone: deny permission, allow in Settings, record/stop, verify 30-second limit. Navigate away or background app while recording; OS microphone indicator stops.
- [ ] Speech: import/record short English and Mexican Spanish clips; allow assets to install; unsupported device/locale gets an error. No-speech clip gets empty-result feedback.
- [ ] Sound Analysis: classify clap, speech, and music recordings; inspect actual confidence scores. Truncated/invalid audio yields an error.
- [ ] Music Understanding: analyze a local unprotected track; all six result fields appear. Invalid/DRM media reports an error. Check memory with a full-length song.
- [ ] Core AI: compatible single-input/output Float32 `.aimodel` yields expected tensor. Wrong name/type/shape fails validation. Invalid model throws a loading error.
- [ ] GPU: run graph and verify [0.880797,0.119203] within tolerance. Profile actual device execution with Instruments.
- [ ] Updates: non-updatable model rejected; valid updatable asset and training rows succeed; export updated model and compare held-out predictions. Wrong label/schema fails visibly.
- [ ] AR: deny/allow camera; unsupported device gets capability message. Supported device tracks a visible person's 3D joints. Navigation/background stops camera; interruption is visible.
- [ ] Storage: chosen files don't modify originals. Temporary session imports are removed on next launch; exported updated model remains available in Files.
- [ ] Offline: after required system assets are installed, test supported demos in airplane mode. No automatic cloud fallback occurs in the app code.

## Packaging checks completed in the creation environment

See VALIDATION.txt. These do not establish Xcode compilation, native runtime correctness, model inference, or visual UI quality.
