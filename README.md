# Liquid LLM

Liquid LLM is an iOS 27+ SwiftUI chat app built around Apple Foundation Models, Core AI, and Liquid Glass UI.

## Build

Use the Xcode 27 beta toolchain:

```bash
DEVELOPER_DIR=/Volumes/SSD/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild \
  -project LiquidLLM.xcodeproj \
  -scheme LiquidLLM \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The target is device-only because the installed iOS 27 simulator SDK does not include `CoreAI.framework`. The iPhoneOS 27 SDK does include Core AI, and the generic iOS build succeeds.

## Model Downloads

The model library searches Hugging Face text-generation repositories and downloads files that can form a Core AI language bundle: `metadata.json`, `.aimodel` / `.aimodelc` assets, tokenizer files, and generation config files. Downloaded bundles are inspected locally before they are enabled for chat.
