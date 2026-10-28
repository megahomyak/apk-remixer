#!/usr/bin/bash
set -e

in="$1"
out="${in}.remixed.apk"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# 1. Decompile
apktool d -f "$in" -o "$tmp"

# 2. Set a random package name
pkg="com.$(tr -dc 'a-z' </dev/urandom | head -c 30)"
sed -i "s/package=\"[^\"]*\"/package=\"$pkg\"/" "$tmp/AndroidManifest.xml"
# Set target SDK version to 24
sed -i "s/targetSdkVersion: .*/targetSdkVersion: '24'/" "$tmp/apktool.yml"

# 3. Rebuild
apktool b "$tmp" -o "$tmp/rebuilt.apk"

# 4. Align
zipalign -f 4 "$tmp/rebuilt.apk" "$tmp/aligned.apk"

# 5. Generate ephemeral key
keytool -genkeypair -v \
  -keystore "$tmp/ks.p12" -storetype PKCS12 \
  -alias key -keyalg RSA -keysize 2048 -validity 1 \
  -storepass password -keypass password \
  -dname "CN=Android Debug,O=Android,C=US"

# 6. Sign
apksigner sign --ks "$tmp/ks.p12" \
  --ks-pass pass:password --key-pass pass:password \
  --out "$out" "$tmp/aligned.apk"

# (cleanup happens automatically via trap)
