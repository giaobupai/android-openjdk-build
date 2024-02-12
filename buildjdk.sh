#!/bin/bash
set -euo pipefail
. setdevkitpath.sh

export FREETYPE_DIR=$PWD/freetype-$BUILD_FREETYPE_VERSION/build_android-$TARGET_SHORT
export CUPS_DIR=$PWD/cups-2.4.7
export CFLAGS+=" -DLE_STANDALONE -DANDROID -pipe -integrated-as -fno-plt -Ofast -flto -mllvm -polly -mllvm -polly-vectorizer=stripmine -mllvm -polly-invariant-load-hoisting -mllvm -polly-run-inliner -mllvm -polly-run-dce" # -I"$FREETYPE_DIR" -I"$CUPS_DI"
if [[ "$TARGET_JDK" == "arm" ]] # || [[ "$BUILD_IOS" == "1" ]]
then
  export CFLAGS+=" -D__thumb__"
else
  if [[ "$TARGET_JDK" == "x86" ]]; then
     export CFLAGS+=" -mstackrealign"
  fi
fi

if [[ "$TARGET_JDK" == "aarch32" ]] || [[ "$TARGET_JDK" == "aarch64" ]]
then
  export CFLAGS+=" -march=armv7-a+neon"
fi

# It isn't good, but need make it build anyways
# cp -R $CUPS_DIR/* $ANDROID_INCLUDE/

# cp -R /usr/include/X11 $ANDROID_INCLUDE/
# cp -R /usr/include/fontconfig $ANDROID_INCLUDE/

if [[ "$BUILD_IOS" != "1" ]]; then
  chmod +x android-wrapped-clang
  chmod +x android-wrapped-clang++
  ln -s -f /usr/include/X11 "$ANDROID_INCLUDE"/
  ln -s -f /usr/include/fontconfig "$ANDROID_INCLUDE"/
  platform_args="--with-freetype-include=$FREETYPE_DIR/include/freetype2 \
    --with-freetype-lib=$FREETYPE_DIR/lib \
    "
  AUTOCONF_x11arg="--x-includes="$ANDROID_INCLUDE"/X11"

  export CFLAGS+=" -DANDROID"
  export LDFLAGS+=" -L$PWD/dummy_libs"

# Create dummy libraries so we won't have to remove them in OpenJDK makefiles
  mkdir -p dummy_libs
  ar cr dummy_libs/libpthread.a
  ar cr dummy_libs/librt.a
  ar cr dummy_libs/libthread_db.a
else
  ln -s -f /opt/X11/include/X11 "$ANDROID_INCLUDE"/
  ln -sfn "$themacsysroot"/System/Library/Frameworks/CoreAudio.framework/Headers "$ANDROID_INCLUDE"/CoreAudio
  ln -sfn "$themacsysroot"/System/Library/Frameworks/IOKit.framework/Headers "$ANDROID_INCLUDE"/IOKit
  if [[ "$(uname -p)" == "arm" ]]; then
    ln -s -f /opt/homebrew/include/fontconfig "$ANDROID_INCLUDE"/
  else
    ln -s -f /usr/local/include/fontconfig "$ANDROID_INCLUDE"/
  fi
  platform_args="--with-sysroot=$(xcrun --sdk iphoneos --show-sdk-path) \
    --with-boot-jdk=$(/usr/libexec/java_home -v 17) \
    --with-freetype=bundled"
  AUTOCONF_x11arg="--with-x=/opt/X11/include/X11 --prefix=/usr/lib"
  sameflags="-arch arm64 -DHEADLESS=1 -I$PWD/ios-missing-include -Wno-implicit-function-declaration -DTARGET_OS_OSX"
  export CFLAGS+=" $sameflags"
  export LDFLAGS+="-arch arm64"
  export BUILD_SYSROOT_CFLAGS="-isysroot ${themacsysroot:-}"

  HOMEBREW_NO_AUTO_UPDATE=1 brew install fontconfig ldid xquartz autoconf
fi

# fix building libjawt
ln -s -f "$CUPS_DIR"/cups "$ANDROID_INCLUDE"/

cd openjdk

# Apply patches
git reset --hard
if [[ "$BUILD_IOS" != "1" ]]; then
  git apply --reject --whitespace=fix ../patches/jdk17u_android.diff || echo "git apply failed (Android patch set)"
else
  git apply --reject --whitespace=fix ../patches/jdk17u_ios.diff || echo "git apply failed (iOS patch set)"

  # Hack: exclude building macOS stuff
  desktop_mac=src/java.desktop/macosx
  mv ${desktop_mac} ${desktop_mac}_NOTIOS
  mkdir -p ${desktop_mac}/native
  mv ${desktop_mac}_NOTIOS/native/libjsound ${desktop_mac}/native/
fi

# rm -rf build

#   --with-extra-cxxflags="$CXXFLAGS -Dchar16_t=uint16_t -Dchar32_t=uint32_t" \
#   --with-extra-cflags="$CPPFLAGS" \

env -u CFLAGS -u LDFLAGS 
bash ./configure \
  --with-version-pre=- \
  --openjdk-target="$TARGET" \
  --with-extra-cflags="$CFLAGS" \
  --with-extra-cxxflags="$CFLAGS" \
  --with-extra-ldflags="$LDFLAGS" \
  --disable-precompiled-headers \
  --disable-warnings-as-errors \
  --enable-option-checking=fatal \
  --enable-headless-only=yes \
  --with-toolchain-type=clang \
  --with-jvm-variants=$JVM_VARIANTS \
  --with-jvm-features=-dtrace,-zero,-vm-structs,-epsilongc \
  --with-cups-include="$CUPS_DIR" \
  --with-devkit="$TOOLCHAIN" \
  --with-debug-level=$JDK_DEBUG_LEVEL \
  --with-fontconfig-include="$ANDROID_INCLUDE" \
  "$AUTOCONF_x11arg" "${AUTOCONF_EXTRA_ARGS:-}" \
  --x-libraries=/usr/lib \
  AR="$AR" \
  NM="$NM" \
  OBJCOPY="$OBJCOPY" \
  OBJDUMP="$OBJDUMP" \
  STRIP="$STRIP" \
  ${platform_args:-} ||
  error_code=$?
if [[ "${error_code:-0}" -ne 0 ]]; then
  echo -e "\n\nCONFIGURE ERROR $error_code , config.log:"
  cat config.log
  exit $error_code
fi

cd build/${JVM_PLATFORM}-"${TARGET_JDK}"-${JVM_VARIANTS}-${JDK_DEBUG_LEVEL}
make JOBS="$(nproc)" images ||
  error_code=$?
if [[ "${error_code:-0}" -ne 0 ]]; then
  echo "Build failure, exited with code $error_code. Trying again."
  make JOBS="$(nproc)" images
fi
