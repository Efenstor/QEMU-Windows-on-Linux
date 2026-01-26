Run Windows 10 or 7 under Linux in a QEMU VM
==

A script facilitating running Windows 10 or Windows 7 in a QEMU virtual machine on a x86-64 Linux host.

Features:

* Fastest KVM features pre-enabled
* Easy sharing of USB devices (see the section below)
* Shared folder with symbolic links allowed
* GTK and Spice version (for Wayland use GTK, for X11 use Spice)

## Prerequisites

* QEMU
* Samba
* virt-viewer (for Spice)

## Usage

Copy the script somewhere, open it with a text editor and tweak the variables at the beginning of the file as needed.

## Installing Windows

If you have no Windows installed yet, create an empty qcow2 image, for example:

    qemu-img create -f qcow2 windows_10.qcow2 128G

Then open the script and set the IMG variable to the qcow2 file, INSTALL_DISK to your Windows installation media (ISO or physical media), then run the script.

Once Windows is installed download and install:

* [WinCDEmu](https://wincdemu.sysprogs.org/): it is needed for mounting ISO files with the drivers
* Drivers for Windows 10: *virtio-win-0.1.248.iso* and *virtio-win-guest-tools.exe* ([download](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.248-1/))
* Drivers for Windows 7: *virtio-win-0.1.173.iso* ([download](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.173-9/))

## Sharing USB devices

Besides listing your devices in the USB variable in the script, you have to lower their privileges. Create a file `/etc/udev/rules.d/30-qemu.rules` and add a line of this type for each device:

    SUBSYSTEM=="usb", ATTRS{idVendor}=="VENDOR_ID", ATTRS{idProduct}=="PRODUCT_ID", MODE:="0666"

Replace VENDOR_ID and PRODUCT_ID for the ID data you get using the `lsusb` command.

## Desktop integration

There is a couple of .desktop files in the `desktop` dir. As they are they are intended to be used with the `caffeine` tool which prevents PC from going to sleep (specifically from locking the screen) while VM is running because this situation may cause all sorts of issues.
