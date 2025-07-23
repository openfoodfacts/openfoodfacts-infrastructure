# GPU passthrough configuration on osm45

## Setting up GPU passthrough on osm45

[osm45 server](https://wiki.openstreetmap.org/wiki/FR:Serveurs_OpenStreetMap_France/Moji) was installed in January 2024.
It has 2 NVIDIA 1080 GPUs, which are currently not used.

To access the GPUs from a VM, we need to configure GPU passthrough.

We're following here the official Proxmox documentation on [GPU passthrough](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#qm_pci_passthrough), with the following tutorial as an helpful resource: [Proxmox GPU passthrough with NVIDIA](https://forum.proxmox.com/threads/pci-gpu-passthrough-on-proxmox-ve-8-installation-and-configuration.130218/).

We first run lspci to find the GPU IDs:

```bash
lspci | grep NVIDIA
```

This returns:
```
02:00.0 VGA compatible controller: NVIDIA Corporation GP104 [GeForce GTX 1080] (rev a1)
02:00.1 Audio device: NVIDIA Corporation GP104 High Definition Audio Controller (rev a1)
83:00.0 VGA compatible controller: NVIDIA Corporation GP104 [GeForce GTX 1080] (rev a1)
83:00.1 Audio device: NVIDIA Corporation GP104 High Definition Audio Controller (rev a1)
```

As systemd-boot is used as bootloader, we update the kernel parameters in `/etc/kernel/cmdline` to include the following options:

```intel_iommu=on iommu=pt```

These options were already present in the file.

Next, we add the following lines to `/etc/modules` to load the necessary kernel modules at boot:

```
vfio
vfio_iommu_type1
vfio_pci
```

Then, we refresh the initramfs:

```bash
update-initramfs -u
```

Output:

```
update-initramfs: Generating /boot/initrd.img-6.8.12-10-pve
Running hook script 'zz-proxmox-boot'..
Re-executing '/etc/kernel/postinst.d/zz-proxmox-boot' in new private mount namespace..
Copying and configuring kernels on /dev/disk/by-uuid/E337-49A4
	Copying kernel and creating boot-entry for 6.5.13-6-pve
	Copying kernel and creating boot-entry for 6.8.12-10-pve
	Copying kernel and creating boot-entry for 6.8.12-8-pve
	Removing old version 6.8.8-2-pve
update-initramfs: Generating /boot/initrd.img-6.8.12-8-pve
Running hook script 'zz-proxmox-boot'..
Re-executing '/etc/kernel/postinst.d/zz-proxmox-boot' in new private mount namespace..
Copying and configuring kernels on /dev/disk/by-uuid/E337-49A4
	Copying kernel and creating boot-entry for 6.5.13-6-pve
	Copying kernel and creating boot-entry for 6.8.12-10-pve
	Copying kernel and creating boot-entry for 6.8.12-8-pve
update-initramfs: Generating /boot/initrd.img-6.8.12-7-pve
Running hook script 'zz-proxmox-boot'..
Re-executing '/etc/kernel/postinst.d/zz-proxmox-boot' in new private mount namespace..
Copying and configuring kernels on /dev/disk/by-uuid/E337-49A4
	Copying kernel and creating boot-entry for 6.5.13-6-pve
	Copying kernel and creating boot-entry for 6.8.12-10-pve
	Copying kernel and creating boot-entry for 6.8.12-8-pve
update-initramfs: Generating /boot/initrd.img-6.8.8-2-pve
Running hook script 'zz-proxmox-boot'..
Re-executing '/etc/kernel/postinst.d/zz-proxmox-boot' in new private mount namespace..
Copying and configuring kernels on /dev/disk/by-uuid/E337-49A4
	Copying kernel and creating boot-entry for 6.5.13-6-pve
	Copying kernel and creating boot-entry for 6.8.12-10-pve
	Copying kernel and creating boot-entry for 6.8.12-8-pve
update-initramfs: Generating /boot/initrd.img-6.8.4-3-pve
Running hook script 'zz-proxmox-boot'..
Re-executing '/etc/kernel/postinst.d/zz-proxmox-boot' in new private mount namespace..
Copying and configuring kernels on /dev/disk/by-uuid/E337-49A4
	Copying kernel and creating boot-entry for 6.5.13-6-pve
	Copying kernel and creating boot-entry for 6.8.12-10-pve
	Copying kernel and creating boot-entry for 6.8.12-8-pve
update-initramfs: Generating /boot/initrd.img-6.5.13-6-pve
Running hook script 'zz-proxmox-boot'..
Re-executing '/etc/kernel/postinst.d/zz-proxmox-boot' in new private mount namespace..
Copying and configuring kernels on /dev/disk/by-uuid/E337-49A4
	Copying kernel and creating boot-entry for 6.5.13-6-pve
	Copying kernel and creating boot-entry for 6.8.12-10-pve
	Copying kernel and creating boot-entry for 6.8.12-8-pve
update-initramfs: Generating /boot/initrd.img-6.5.13-5-pve
Running hook script 'zz-proxmox-boot'..
Re-executing '/etc/kernel/postinst.d/zz-proxmox-boot' in new private mount namespace..
Copying and configuring kernels on /dev/disk/by-uuid/E337-49A4
	Copying kernel and creating boot-entry for 6.5.13-6-pve
	Copying kernel and creating boot-entry for 6.8.12-10-pve
	Copying kernel and creating boot-entry for 6.8.12-8-pve
update-initramfs: Generating /boot/initrd.img-6.5.11-4-pve
Running hook script 'zz-proxmox-boot'..
Re-executing '/etc/kernel/postinst.d/zz-proxmox-boot' in new private mount namespace..
Copying and configuring kernels on /dev/disk/by-uuid/E337-49A4
	Copying kernel and creating boot-entry for 6.5.13-6-pve
	Copying kernel and creating boot-entry for 6.8.12-10-pve
	Copying kernel and creating boot-entry for 6.8.12-8-pve
```

I rebooted the server with `systemctl reboot`. I checked that the modules are loaded with:

```bash
lsmod | grep vfio
```

This returns:

```
vfio_pci               16384  0
vfio_pci_core          86016  1 vfio_pci
irqbypass              12288  158 vfio_pci_core,kvm
vfio_iommu_type1       49152  0
vfio                   65536  3 vfio_pci_core,vfio_iommu_type1,vfio_pci
iommufd                94208  1 vfio
```

The modules are indeed loaded correctly.

I checked that the changes were enabled with `dmesg | grep -e DMAR -e IOMMU -e AMD-Vi`:

Output:
```
[    0.009084] ACPI: DMAR 0x000000007BAFE000 000108 (v01 DELL   PE_SC3   00000001 DELL 00000001)
[    0.009117] ACPI: Reserving DMAR table memory at [mem 0x7bafe000-0x7bafe107]
[    0.368420] DMAR: IOMMU enabled
[    0.822582] DMAR: Host address width 46
[    0.822584] DMAR: DRHD base: 0x000000fbffc000 flags: 0x0
[    0.822600] DMAR: dmar0: reg_base_addr fbffc000 ver 1:0 cap 8d2078c106f0466 ecap f020df
[    0.822605] DMAR: DRHD base: 0x000000c7ffc000 flags: 0x1
[    0.822612] DMAR: dmar1: reg_base_addr c7ffc000 ver 1:0 cap 8d2078c106f0466 ecap f020df
[    0.822616] DMAR: RMRR base: 0x00000067ff6000 end: 0x0000006fffdfff
[    0.822621] DMAR: ATSR flags: 0x0
[    0.822626] DMAR: ATSR flags: 0x0
[    0.822630] DMAR-IR: IOAPIC id 10 under DRHD base  0xfbffc000 IOMMU 0
[    0.822634] DMAR-IR: IOAPIC id 8 under DRHD base  0xc7ffc000 IOMMU 1
[    0.822637] DMAR-IR: IOAPIC id 9 under DRHD base  0xc7ffc000 IOMMU 1
[    0.822640] DMAR-IR: HPET id 0 under DRHD base 0xc7ffc000
[    0.822644] DMAR-IR: x2apic is disabled because BIOS sets x2apic opt out bit.
[    0.822645] DMAR-IR: Use 'intremap=no_x2apic_optout' to override the BIOS setting.
[    0.823474] DMAR-IR: Enabled IRQ remapping in xapic mode
[    1.300484] DMAR: [Firmware Bug]: RMRR entry for device 03:00.0 is broken - applying workaround
[    1.300549] DMAR: No SATC found
[    1.300553] DMAR: dmar0: Using Queued invalidation
[    1.300559] DMAR: dmar1: Using Queued invalidation
[    1.314541] DMAR: Intel(R) Virtualization Technology for Directed I/O
```

IOMMU is indeed enabled.

Then, we check that the GPUs are in their own IOMMU groups with:

```bash
pvesh get /nodes/osm45/hardware/pci --pci-class-blacklist ""
```

The first GPU (0000:02:00.0) was in group 29 and the second GPU (0000:83:00.0) was in group 7. Each group contains only one device, which is what we want for passthrough.


### GPU isolation

We get the Vendor and Device IDs of the GPUs with:

```bash
lspci -n | grep NVIDIA
```

Output:
```
02:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP104 [GeForce GTX 1080] [10de:1b80] (rev a1)
02:00.1 Audio device [0403]: NVIDIA Corporation GP104 High Definition Audio Controller [10de:10f0] (rev a1)
83:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP104 [GeForce GTX 1080] [10de:1b80] (rev a1)
83:00.1 Audio device [0403]: NVIDIA Corporation GP104 High Definition Audio Controller [10de:10f0] (rev a1)
```

We use the "blacklist" method to isolate the GPUs from the host system, so that they can be passed through to VMs.

echo "options vfio-pci ids=10de:1b80,10de:10f0" >> /etc/modprobe.d/vfio.conf

Then, we create a file `/etc/modprobe.d/blacklist.conf` with the following content to blacklist the NVIDIA drivers:

```blacklist nouveau
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_modeset
blacklist nvidia_uvm
```

Then, we update the initramfs again:

```bash
update-initramfs -u -k all
```

I rebooted the server again with `systemctl reboot`.

I checked that the NVIDIA drivers are not loaded with:

```bash
lspci -nnk
```

For the GPUs, this returns `Kernel driver in use: vfio-pci`, as expected.


## Creating a VM with GPU passthrough

Next step is to create a VM that will use the GPU passthrough.

I first tried the recommended options for the VM, which are:
- BIOS: OVMF (UEFI)
- Machine: q35

The rest of the parameters are the same as the 2nd attempt I describe below.

When launching the VM, no video output was displayed.
I then tried to use SeaBIOS and i440fx machine type, which are the parameters used by the VM `triton-gpu` described below.

### Info

ID: 201
name: triton-gpu
ISO image: debian-12.6.0-amd64-netinst.iso
BIOS: SeaBIOS
Machine: i440fx
disks: `scsi0`: 100 GB from nvme-zfs for machine
RAM: 30GB (/124 GB)
Cores: 10 (/55), flag: +aes

"Boot on start" was enabled.


### Post-installation

- English
- timezone: France (in others)
- locale: en_US.UTF8
- keymap: french

### Network

Network was manually configured:

- ip address: 10.3.0.201/8
- gateway: 10.0.0.45
- dns server: 9.9.9.9

### Other
Additional contents installed: SSH server. Grub was installed on `/dev/sda`.

I created a user `raphael` with sudo privileges. I installed tmux, vim, git, curl, htop, and uv.

## Configuring the VM for GPU passthrough

I added the PCI devices to the VM configuration with the following commands:

```bash
qm set 201 --hostpci0 02:00
qm set 201 --hostpci1 83:00
```


### Installing NVIDIA drivers

I installed the NVIDIA drivers by following [the following tutorial](https://linuxcapable.com/install-nvidia-drivers-on-debian/).

Install required packages:

```bash
sudo apt install software-properties-common -y
```

Add non-free repository:

```bash
sudo add-apt-repository contrib non-free non-free-firmware
```

Then update with an `apt update`.

We install `nvidia-detect` to detect the GPU model:

```bash
sudo apt install nvidia-detect
```

Run `nvidia-detect` to get the recommended driver:

```bash
nvidia-detect
```

Output:
```
Detected NVIDIA GPUs:
02:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP104 [GeForce GTX 1080] [10de:1b80] (rev a1)
83:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP104 [GeForce GTX 1080] [10de:1b80] (rev a1)

Checking card:  NVIDIA Corporation GP104 [GeForce GTX 1080] (rev a1)
Your card is supported by all driver versions.
Your card is also supported by the Tesla 470 drivers series.
It is recommended to install the
    nvidia-driver
package.

Checking card:  NVIDIA Corporation GP104 [GeForce GTX 1080] (rev a1)
Your card is supported by all driver versions.
Your card is also supported by the Tesla 470 drivers series.
It is recommended to install the
    nvidia-driver
package.
```

We install the recommended driver:

```bash
sudo apt install nvidia-driver
```

We then reboot the VM with:

```bash
sudo reboot
```

### Installing CUDA

Next, we install CUDA by following the instructions on https://developer.nvidia.com/cuda-downloads:

```
wget https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update
sudo apt-get -y install cuda-toolkit-12-9
```

I also installed NVIDIA Container Toolkit to allow Docker to use the GPU:

```bash
sudo apt-get install nvidia-container-toolkit
sudo systemctl restart docker
```

### Installing Triton

First, we clone the Robotoff repository:

```bash
git clone https://github.com/openfoodfacts/robotoff.git
```

After installing git lfs, we activating it with

```bash
git lfs install
```

The rest of the configuration is specific to Triton, which is related to Robotoff.

I installed cuDNN:

```bash
sudo apt-get -y install libcudnn9-cuda-12
```

When sending an inference request to Triton, I got the following error:

```
2025-07-15 12:05:28.393843993 [E:onnxruntime:, sequential_executor.cc:516 ExecuteKernel] Non-zero status code returned while running Cast node. Name:'/text_model/Cast_5' Status Message: CUDA error cudaErrorNoKernelImageForDevice:no kernel image is available for execution on the device
```

It looks like GPUs with compute capability 6.1 (like the GTX 1080) are not supported by the ONNX Runtime version used by Triton.

We could try to build ONNX Runtime from source with support for compute capability 6.1, but it's not officially supported by the current version of Triton (25.X). 
We could also export all models to TensorRT, but the version of TensorRT that supports compute capability 6.1 is old and not compatible with the current version of Triton.

I decided to switch to Triton 23.05, which is the last version that supports compute capability 6.1.
It's possible that some exported models don't work with this version of Triton, as they use operations that are not supported by ONNX IR version 9 (used by Triton 23.05).
I'm testing all models with integration tests to make sure they work with this version of Triton. 

### Model testing

I improved ML integration test supports in Robotoff (PR https://github.com/openfoodfacts/robotoff/pull/1679) and tested the models with the new deployment of Triton 23.05 on the GPU VM.
The following models work well with Triton 23.05 running on the GPU VM:

- `nutrition_table`
- `nutriscore`
- `clip`

The `universal_logo_detector` model returns bogus results (100 detections with confidence 1.0 of `brand` objects).
It seems the model (SavedModel format) is not compatible with this version of Triton on this GPU.

The `price_tag_detection` and `price_proof_classification` models were exported using ONNX IR version 10, which is not supported by Triton 23.05.
We need to export it again with a previous ONNX IR version for it to work.

Using the [compatibility table](https://onnxruntime.ai/docs/reference/compatibility#onnx-opset-support) provided on the ONNX website, as the ONNX runtime of the server is 1.12 (this is displayed at server startup), we know we should use onnx 1.12 (which comes with ONNX IR 8) and a max opset of 17 when exporting the model.

I exported the `price_tag_detection` model with the following command (Python3.10, `ultralytics==8.3.168;onnx==1.12`):

```bash
uv run ultralytics export model=best.pt format=onnx imgsz=960 opset=17
```

The `price_tag_detection` model is now loaded correctly by Triton 23.05 on the GPU VM. I pushed the model to HF (https://huggingface.co/openfoodfacts/price-tag-detection/commit/2a1499bcd4a72ea9f49d24335e1f822d2a35cdaf).

Similarly, I exported the `price_proof_classification` model with the same command, deployed it on GPU and pushed it to HF (https://huggingface.co/openfoodfacts/price-proof-classification/commit/03c3bad38f4135d755584c346769f3217231cb36).

I also added to Robotoff the ability to specify the Triton URI for each model (PR https://github.com/openfoodfacts/robotoff/pull/1682).