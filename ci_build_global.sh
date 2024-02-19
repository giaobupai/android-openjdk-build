#!/bin/bash
set -e
. setdevkitpath.sh

export JDK_DEBUG_LEVEL=release

chmod +x android-wrapped-clang
chmod +x android-wrapped-clang++

sudo chmod 777 extractndk.sh
sudo chmod 777 maketoolchain.sh

if [[ "$BUILD_IOS" != "1" ]]; then

  if [[ -z "$NDK_USE_EXISTING" ]]; then
    wget -nc -nv -O android-ndk-$NDK_VERSION-linux-x86_64.zip "https://dl.google.com/android/repository/android-ndk-$NDK_VERSION-linux-x86_64.zip"
    ./extractndk.sh
    ./maketoolchain.sh
  fi
else
  chmod +x ios-arm64-clang
  chmod +x ios-arm64-clang++
  chmod +x macos-host-cc
fi

# Some modifies to NDK to fix

sudo chmod 777 getbootjdk.sh
sudo chmod 777 getlibs.sh
sudo chmod 777 buildlibs.sh
sudo chmod 777 clonejdk.sh
sudo chmod 777 buildjdk.sh
sudo chmod 777 removejdkdebuginfo.sh
sudo chmod 777 tarjdk.sh

./getbootjdk.sh
./getlibs.sh
./buildlibs.sh
./clonejdk.sh
./buildjdk.sh
./removejdkdebuginfo.sh
./tarjdk.sh
