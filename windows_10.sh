#!/bin/sh
# Script made by Efenstor in 2020
# Modified in 2026

IMG="$HOME/qemu/windows_10.qcow2"  # VM disk file name
INSTALL_DISK=  # Installation media
RRAM=4  # amount of RAM reserved in GB
RCPUS=2  # number of CPUs reserved
SHARED_DIR="$HOME"/Public  # Shared directory
NAME="Windows 10"  # VM name

# Shared USB devices, one device per line
# The format is "vendor_id,product_id,bus  # comment"
# Example: 04f9,0090,xhci0.0  # Brother HL-L8260CDW

USB="
"

USE_VIRTIO_GPU_GL=0  # use virtio-gpu-gl
VGA=virtio  # default=virtio, set to 'none' if using virtio-gpu-gl
CPUS=  # manually set the number of CPUs
RAM=  # manually set the amount of RAM, e.g. 12G (don't forget M or G)
IMG_OPTIONS="format=qcow2,cache=writeback,l2-cache-size=128K"  # VM disk image options


# == don't touch anything past this line ==

parse_usb() {
  usb_args=
  while [ -n "$USB" ]; do
    # get line
    line=$(echo "$USB" | head -n 1)
    USB=$(echo "$USB" | tail -n +2)
    # strip of extras
    l=$(echo "$line" | sed "s/ *#.*//")
    if [ ! "$l" ]; then continue; fi
    # fields
    vendor=$(echo "$l" | cut -d, -f1 | sed "s/ *//")
    product=$(echo "$l" | cut -d, -f2 | sed "s/ *//")
    bus=$(echo "$l" | cut -d, -f3 | sed "s/ *//")
    comment=$(echo "$line" | sed "s/.*# //")
    printf "  vendor=0x$vendor; product=0x$product; bus=$bus.0"
    if [ "$comment" ]; then
      printf "; comment=$comment\n"
    else
      printf "\n"
    fi
    # add to the arguments
    usb_args="$usb_args""-usb -device usb-host,vendorid=0x$vendor,productid=0x$product,bus=$bus.0 "
  done
  if [ ! "$usb_args" ]; then
    echo "  none"
  fi
}

# Check for the required tools
tools="qemu-system-x86_64 smbcontrol"
for i in $tools; do
  if ! which -s "$i"; then
    echo "$i program not found."
    exit
  fi
done

# Check if VM image is there
if [ ! -f "$IMG" ]; then
  echo "VM not found!"
  exit
fi

# Using CD-ROM
if [ -e "$INSTALL_DISK" ]; then
  CDROM="-cdrom \"$INSTALL_DISK\""
else
  CDROM=
fi

# Detect memory and CPUs
if [ ! "$RAM" ]; then
  memkb=$(cat /proc/meminfo | grep "MemTotal: " | sed "s/.*: *//;s/ .*//")
  RAM=$(printf "%.0fG" $(echo "( 32778164 / 1024 / 1024 ) - $RRAM" | bc -l))
  echo "Using VM RAM = $RAM ("$RRAM"G reserved)"
else
  echo "Using VM RAM = $RAM"
fi
if [ ! "$CPUS" ]; then
  CPUS=$(nproc --ignore=$RCPUS)
  echo "Using VM CPUs = $CPUS ($RCPUS reserved)"
else
  echo "Using VM CPUs = $CPUS"
fi

# virtio-gpu-gl
if [ $USE_VIRTIO_GPU_GL -eq 1 ]; then
  VIRTIO_GPU_GL="-device virtio-gpu-gl-pci"
fi

# USB devices
echo "USB devices to be added:"
parse_usb

# Start QEMU
echo "Starting QEMU..."
eval qemu-system-x86_64 -k ru \
  -machine q35,accel=kvm \
  -cpu host,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_vpindex,hv_synic,hv_time,hv_stimer,hv_ipi,hv_runtime,hv_reset,hv_frequencies,hv_reenlightenment,hv_tlbflush \
  -smp cpus=$CPUS -m size=$RAM \
  -vga $VGA \
  -display gtk,gl=on,show-menubar=off,zoom-to-fit=on -rtc base=localtime,clock=host \
  -nic user,model=e1000,ipv6=off,smb=\"$SHARED_DIR\" \
  -drive id=bootdisk,file=\"$IMG\",$IMG_OPTIONS,if=none \
  $CDROM \
  -device ahci,id=ahci0 \
  -device ide-hd,drive=bootdisk,bus=ahci0.0 \
  $VIRTIO_GPU_GL \
  -device virtio-balloon \
  -audiodev pa,driver=pa,id=pa0 -device ich9-intel-hda -device hda-output,audiodev=pa0 \
  -name \"$NAME\" \
  -usb -device nec-usb-xhci,id=xhci0 \
  -usb -device usb-ehci,id=ehci0 \
  -usb -device usb-ehci,id=ehci1 \
  -device usb-tablet,bus=ehci0.0 \
  -device usb-kbd,bus=ehci1.0 \
  $usb_args & QEMU_PID=$!

# Wait a bit and check if the QEMU process still exists
sleep 1
if ! ps -p $QEMU_PID > /dev/null; then
  echo "QEMU cannot start."
  exit
fi

if [ ! "$CDROM" ]; then
  # Wait until the QEMU Samba server starts
  echo "Wait for the QEMU Samba server to start..."
  while :
  do
    if ps h -C smbd -o pid,args | grep /tmp/qemu-smb > /dev/null; then
      break
    fi
    sleep .25
  done

  # Modify the QEMU Samba server config to allow symbolic links
  # Source: https://wiki.archlinux.org/title/QEMU
  echo "Modifying Samba config to allow symbolic links..."
  eval $(ps h -C smbd -o pid,args | grep /tmp/qemu-smb | gawk '{print "pid="$1";conf="$6}')
  echo "[global]
  allow insecure wide links = yes
  [qemu]
  follow symlinks = yes
  wide links = yes
  acl allow execute always = yes" >> "$conf"
  # in case the change is not detected automatically:
  smbcontrol --configfile="$conf" "$pid" reload-config
fi

# Wait until QEMU is done
echo "Waiting for QEMU to exit..."
while :
do
  if ! ps -p $QEMU_PID > /dev/null; then
    break
  fi
  sleep .25
done

echo "Done."
