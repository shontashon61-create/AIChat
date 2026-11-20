#!/bin/bash
# Сборка неподписанного IPA. Запускать ТОЛЬКО на macOS с установленным Xcode.
# На Windows напрямую собрать IPA нельзя - нужен Mac или GitHub Actions (см. README.md).
set -e
cd "$(dirname "$0")"
rm -rf build Payload AIChat-unsigned.ipa
xcodebuild -project AIChat.xcodeproj -scheme AIChat -configuration Release -sdk iphoneos -derivedDataPath build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
mkdir -p Payload
cp -r "build/Build/Products/Release-iphoneos/AIChat.app" Payload/
zip -r AIChat-unsigned.ipa Payload
rm -rf Payload
ls -lh AIChat-unsigned.ipa
