#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
revision=2a280f5a231966dc5d1b534978dd9f9f04a374cd
if [ ! -d .tools/CascLib/.git ]; then
  mkdir -p .tools
  git clone https://github.com/ladislav-zezula/CascLib.git .tools/CascLib
  git -C .tools/CascLib checkout "$revision"
fi
actual=$(git -C .tools/CascLib rev-parse HEAD)
if [ "$actual" != "$revision" ]; then
  echo "Unexpected CascLib revision: $actual" >&2
  exit 1
fi
# Upstream's two existence probes request write access unnecessarily. Keep the
# local game installation strictly read-only, including under the sandbox.
python3 - <<'PY'
from pathlib import Path
p = Path('.tools/CascLib/src/CascFiles.cpp')
data = p.read_bytes()
for variable in (b'szFileName', b'szLocalPath'):
    data = data.replace(b'FileStream_OpenFile(' + variable + b', 0)',
                        b'FileStream_OpenFile(' + variable + b', STREAM_FLAG_READ_ONLY)')
p.write_bytes(data)
PY
cmake -S .tools/CascLib -B .tools/casc-build \
  -DCASC_BUILD_SHARED_LIB=OFF -DCASC_BUILD_STATIC_LIB=ON \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build .tools/casc-build -j 6
c++ -std=c++17 -O2 -DCASCLIB_NO_AUTO_LINK_LIBRARY -DCASCLIB_NODEBUG \
  -I .tools/CascLib/src tools/casc/extract.cpp .tools/casc-build/libcasc.a \
  -lz -o .tools/casc-extract
