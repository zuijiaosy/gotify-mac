#!/bin/bash
# swift test 包装：纯 CLT 环境下 Testing.framework 与 lib_TestingInterop.dylib
# 不在默认搜索路径，必须显式指定，否则报 "no such module 'Testing'" 或 dlopen 失败。
# 用法: scripts/test.sh [swift test 的其他参数]
set -euo pipefail

cd "$(dirname "$0")/.."

CLT_FRAMEWORKS=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
CLT_TESTLIB=/Library/Developer/CommandLineTools/Library/Developer/usr/lib

exec swift test \
  -Xswiftc -F -Xswiftc "$CLT_FRAMEWORKS" \
  -Xlinker -F -Xlinker "$CLT_FRAMEWORKS" \
  -Xlinker -rpath -Xlinker "$CLT_FRAMEWORKS" \
  -Xlinker -rpath -Xlinker "$CLT_TESTLIB" \
  "$@"
