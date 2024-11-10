#!/bin/bash

set -euo pipefail

SOURCE=./src/
DEST=./out/
C2W_V="${C2W:-c2w}"
C2W_EXTRA_FLAGS_V=${C2W_EXTRA_FLAGS:-}
QEMU_WASM_REPO_V="${QEMU_WASM_REPO}"

# /image : image name
# /Dockerfile : dockerfile to use
# /arch : image architecture (default: amd64)

function generate() {
    local TARGETARCH="${1}"
    local IMAGE="${2}"
    local OUTPUT="${3}"

    if [ "${TARGETARCH}" = "aarch64" ] ; then
        ${C2W_V} --to-js --build-arg LOAD_MODE=separated --target-arch="${TARGETARCH}" ${C2W_EXTRA_FLAGS_V} "${IMAGE}" "${OUTPUT}"
    elif [ "${TARGETARCH}" = "amd64" ] ; then
        ${C2W_V} --target-stage=js-qemu-amd64 --build-arg LOAD_MODE=separated ${C2W_EXTRA_FLAGS_V} "${IMAGE}" "${OUTPUT}"
    else
        echo "unknown arch ${TARGETARCH}"
        exit 1
    fi
}

mkdir "${DEST}"
ls "${DEST}"

for I in $(ls -1 ${SOURCE}) ;
do
    OUTPUT_NAME="${I}-container"
    TARGETARCH=$(cat "${SOURCE}/${I}/arch" || true)
    if [ "${TARGETARCH}" == "" ] ; then
        TARGETARCH="amd64"
    fi
    mkdir "${DEST}/${I}"
    if [ -f "${SOURCE}/${I}/image" ]; then
        generate "${TARGETARCH}" "$(cat ${SOURCE}/${I}/image)" "${DEST}/${I}/"
    elif [ -f "${SOURCE}/${I}/Dockerfile" ]; then
        cat ${SOURCE}/${I}/Dockerfile | docker buildx build --progress=plain -t ${I} --platform="linux/${TARGETARCH}" --load -
        generate "${TARGETARCH}" "${I}" "${DEST}/${I}/"
    else
        echo "no image source found for ${I}"
        exit 1
    fi
done

docker build -t buildqemu-tmp - < "${QEMU_WASM_REPO_V}/Dockerfile"
docker run --rm -d --name build-qemu-wasm-tmp -v "${QEMU_WASM_REPO_V}":/qemu/:ro buildqemu-tmp
EXTRA_CFLAGS="-O3 -g -Wno-error=unused-command-line-argument -matomics -mbulk-memory -DNDEBUG -DG_DISABLE_ASSERT -D_GNU_SOURCE -sASYNCIFY=1 -pthread -sPROXY_TO_PTHREAD=1 -sFORCE_FILESYSTEM -sALLOW_TABLE_GROWTH -sTOTAL_MEMORY=2300MB -sWASM_BIGINT -sMALLOC=mimalloc --js-library=/build/node_modules/xterm-pty/emscripten-pty.js -sEXPORT_ES6=1 "
docker exec -it build-qemu-wasm-tmp emconfigure /qemu/configure --static --target-list=aarch64-softmmu --cpu=wasm32 --cross-prefix= \
       --without-default-features --enable-system --with-coroutine=fiber \
       --extra-cflags="$EXTRA_CFLAGS" --extra-cxxflags="$EXTRA_CFLAGS" --extra-ldflags="-sEXPORTED_RUNTIME_METHODS=getTempRet0,setTempRet0,addFunction,removeFunction,TTY"
docker exec -it build-qemu-wasm-tmp emmake make -j $(nproc) qemu-system-aarch64

TMPDIR=$(mktemp -d)

mkdir "${TMPDIR}/pack"
docker build --output=type=local,dest="${TMPDIR}/pack" "${QEMU_WASM_REPO_V}"/examples/raspi3ap-qemu/image/
docker cp "${TMPDIR}/pack" build-qemu-wasm-tmp:/
docker exec -it build-qemu-wasm-tmp /bin/sh -c "/emsdk/upstream/emscripten/tools/file_packager.py qemu-system-aarch64.data --preload /pack > load.js"

mkdir "${DEST}/raspi3ap"
docker cp build-qemu-wasm-tmp:/build/qemu-system-aarch64 "${DEST}/raspi3ap/out.js"
for f in qemu-system-aarch64.wasm qemu-system-aarch64.worker.js qemu-system-aarch64.data load.js ; do
    docker cp build-qemu-wasm-tmp:/build/${f} "${DEST}/raspi3ap/"
done

docker kill build-qemu-wasm-tmp
rm -r "${TMPDIR}"
