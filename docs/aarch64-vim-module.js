if (typeof Module === 'undefined') {
    Module = {};
}
Module['arguments'] = [
    '-cpu', 'cortex-a53', '-machine', 'virt',
    '-bios', '/edk2/edk2-aarch64-code.fd',
    '-m', '512M', '-accel', 'tcg,tb-size=500',
    '-nic', 'none',
    '-drive', 'if=virtio,format=raw,file=/rootfs/rootfs.bin',
    '-kernel', '/image/bzImage',
    '-append', 'earlyprintk=hvc0 console=hvc0 root=/dev/vda rootwait ro loglevel=6 NO_RUNTIME_CONFIG=1 init=/sbin/tini -- /sbin/init',
    '-device', 'virtio-serial,id=virtio-serial0',
    '-chardev', 'stdio,id=charconsole0,mux=on',
    '-device', 'virtconsole,chardev=charconsole0,id=console0'
];
Module['locateFile'] = function(path, prefix) {
    return '/qemu-wasm-demo/images/aarch64-vim/' + path;
};
Module['mainScriptUrlOrBlob'] = '/qemu-wasm-demo/images/aarch64-vim/out.js'
