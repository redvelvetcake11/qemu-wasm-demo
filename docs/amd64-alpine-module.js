if (typeof Module === 'undefined') {
    Module = {};
}
Module['arguments'] = [
    '-nographic', '-m', '512M', '-accel', 'tcg,tb-size=500',
    '-L', '/bios/',
    '-nic', 'none',
    '-drive', 'if=virtio,format=raw,file=/rootfs/rootfs.bin',
    '-kernel', '/image/bzImage',
    '-append', 'earlyprintk=ttyS0,115200n8 console=ttyS0,115200n8 root=/dev/vda rootwait ro loglevel=6 NO_RUNTIME_CONFIG=1 init=/sbin/tini -- /sbin/init',
];
Module['locateFile'] = function(path, prefix) {
    return '/images/amd64-alpine/' + path;
};
Module['mainScriptUrlOrBlob'] = '/images/amd64-alpine/out.js'
