#!/bin/bash
set -euo pipefail

git clone -b jdk-17.0.10+6_adopt --depth 1 https://github.com/adoptium/jdk17u openjdk
