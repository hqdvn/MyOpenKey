#!/bin/bash
set -e

echo "==> [macOS Keys] Running engine regression test..."
clang++ -std=c++17 -g -fsanitize=address,undefined -fno-sanitize-recover=all \
  -I Sources/OpenKey/engine \
  Sources/OpenKey/engine/*.cpp Tests/engine_test.cpp \
  -o /tmp/engine_test && /tmp/engine_test

echo ""
echo "==> [Win32 Keys] Running engine regression test with -DOPENKEY_WIN32_KEYS..."
clang++ -std=c++17 -g -fsanitize=address,undefined -fno-sanitize-recover=all \
  -DOPENKEY_WIN32_KEYS \
  -I Sources/OpenKey/engine \
  Sources/OpenKey/engine/*.cpp Tests/engine_test.cpp \
  -o /tmp/engine_test_win32 && /tmp/engine_test_win32

echo ""
echo "==> [Chunk Splitter] Running chunk splitter regression test..."
clang++ -std=c++14 Tests/chunk_test.cpp -I Sources/OpenKey/macOS/ModernKey -o /tmp/chunk_test && /tmp/chunk_test
