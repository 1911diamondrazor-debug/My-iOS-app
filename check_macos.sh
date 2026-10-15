#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -version
xcrun swift Tools/VerifyModel.swift MLLab/Resources/TinyRegressor.mlmodel
xcodebuild -project MLLab.xcodeproj -scheme MLLab -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/MLLabDerivedData CODE_SIGNING_ALLOWED=NO build
