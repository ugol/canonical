#!/bin/bash
set -o errexit -o nounset -o pipefail

# Configuration 
WORKDIR="$PWD/qemu_hello"
DISK="$WORKDIR/rootfs.img"
MOUNTDIR="$WORKDIR/mnt"
DISKSIZE=64M  
KERNEL_URL="https://kernel.ubuntu.com/mainline/v6.11/amd64/linux-image-unsigned-6.11.0-061100-generic_6.11.0-061100.202409151536_amd64.deb"

# VERBOSE controls kernel boot output
# Usage:
#   VERBOSE=1 ./script.sh  # verbose boot (no quiet)
#   ./script.sh            # quiet boot by default
: "${VERBOSE:=}"

if [ -z "$VERBOSE" ]; then
    KERNEL_CMDLINE="root=/dev/sda rw console=ttyS0 init=/init quiet"
else
    KERNEL_CMDLINE="root=/dev/sda rw console=ttyS0 init=/init"
fi

# Cleanup function 
cleanup() {
    if mountpoint -q "$MOUNTDIR"; then
        echo "[*] Unmounting $MOUNTDIR"
        sudo umount "$MOUNTDIR" || true
    fi
}
trap cleanup EXIT

# Check required tools 
for tool in qemu-system-x86_64 gcc mkfs.ext4 curl ar tar; do
    if ! command -v "$tool" &>/dev/null; then
        echo "[-] Required command '$tool' is not installed."
        exit 1
    fi
done

# Check sudo permissions upfront
if ! sudo -v; then
    echo "[-] sudo privileges are required to mount/unmount the disk image."
    exit 1
fi

# Create workdir
echo "[*] Creating workdir at: $WORKDIR"
mkdir -p "$WORKDIR" "$MOUNTDIR"
cd "$WORKDIR"

# Download & extract kernel 
if [ ! -f "bzImage" ]; then
    echo "[*] Downloading Ubuntu prebuilt kernel..."
    curl -LO "$KERNEL_URL"

    DEBFILE=$(basename "$KERNEL_URL")

    echo "[*] Extracting kernel image..."
    if ! ar x "$DEBFILE"; then
        echo "[-] Failed to extract $DEBFILE"
        exit 1
    fi

    if ! tar --wildcards -xf data.tar ./boot/vmlinuz-*; then
        echo "[-] Failed to extract kernel from data.tar"
        exit 1
    fi

    mv boot/vmlinuz* bzImage
    chmod +x bzImage

    # Clean intermediate files
    rm -rf boot data.tar control.tar "$DEBFILE"
fi

# Build static init 
echo '[*] Building minimal init program...'
mkdir -p src

cat > src/init.c <<'EOF'
#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <sys/reboot.h>

int main() {
    const char* hello = "Hello, world!\n";
    const char* exit_msg = "Press RETURN to exit\n";
    int fd = open("/dev/console", O_RDWR);

    if (fd >= 0) {
        write(fd, hello, strlen(hello));
        write(fd, exit_msg, strlen(exit_msg));

        char ch;
        for (;;) {
            if (read(fd, &ch, 1) != 1) continue;
            if (ch == '\n') break;
        }
        write(fd, "Shutting down...\n", 18);
        sync();
        reboot(RB_POWER_OFF);
    } else {
        write(STDERR_FILENO, "Could not open /dev/console\n", 28);
    }

    for (;;) pause();
    return 0;
}
EOF

gcc -static -o init src/init.c

# Create ext4 root filesystem 
echo "[*] Creating root disk image..."
qemu-img create -f raw "$DISK" "${DISKSIZE}"
mkfs.ext4 -F "$DISK"

echo "[*] Mounting disk image..."
sudo mount -o loop "$DISK" "$MOUNTDIR"

echo "[*] Populating root filesystem..."
sudo mkdir -p "$MOUNTDIR"/{dev,proc,sys}
sudo cp init "$MOUNTDIR/init"
sudo chmod +x "$MOUNTDIR/init"
sudo chown root:root "$MOUNTDIR/init"

echo "[*] Creating device nodes..."
sudo mknod -m 666 "$MOUNTDIR/dev/null" c 1 3
sudo mknod -m 666 "$MOUNTDIR/dev/zero" c 1 5
sudo mknod -m 600 "$MOUNTDIR/dev/console" c 5 1
sudo chown root:root "$MOUNTDIR/dev/"*

echo "[*] Unmounting disk image..."
sudo umount "$MOUNTDIR"

# Run the Kernel!
echo "[*] Booting with QEMU..."
qemu-system-x86_64 \
    -kernel bzImage \
    -hda "$DISK" \
    -append "$KERNEL_CMDLINE" \
    -nographic

