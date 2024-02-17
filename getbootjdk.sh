#!/bin/bash
set -e
. setdevkitpath.sh

# Temp script to get jdk23
# These cases are hardcoded to:
# - Linux amd64
# - macOS arm64
# Please change if you have different architecture.

  wget https://download.java.net/java/early_access/jdk23/10/GPL/openjdk-23-ea+10_linux-x64_bin.tar.gz
tar xvf openjdk-23*.tar.gz
