# Flash operation instructions for Jetson AGX Thor series modules on the Y-C28 carrier board

##  Precondition

- A separate Linux (Ubuntu 22.04 or Ubuntu 20.04) host system.
- Linux host is connected for flashing through the appropriate USB Type-C port of the developer kit.

## Usage

- \<real-time>  represents the actual path you use for flashing the device.

  The first line of each code segment in the document is designed to ensure that the corresponding command is executed in the correct path.

### 1.  Create a work directory

```shell
mkdir <real-dir>/workspaces && cd <real-dir>/workspaces
mkdir flash nvtools source
```

### 2. Build the flash environment

#### 2.1 Download and extract the NVIDIA Driver Package (BSP)

```shell
cd <real-dir>/workspaces/flash
wget https://developer.nvidia.com/downloads/embedded/L4T/r38_Release_v2.1/release/Jetson_Linux_R38.2.1_aarch64.tbz2
tar -xf Jetson_Linux_R38.2.1_aarch64.tbz2
```

#### 2.2 Download and extract the NVIDIA  Sample Root Filesystem

```shell
cd <real-dir>/workspaces/flash
wget https://developer.nvidia.com/downloads/embedded/L4T/r38_Release_v2.1/release/Tegra_Linux_Sample-Root-Filesystem_R38.2.1_aarch64.tbz2
sudo tar -xpf Tegra_Linux_Sample-Root-Filesystem_R38.2.1_aarch64.tbz2 -C Linux_for_Tegra/rootfs/
```

#### 2.3 Install flash Env prerequisites

```shell
cd <real-dir>/workspaces/flash/Linux_for_Tegra
sudo ./tools/l4t_flash_prerequisites.sh
```

#### 2.4 Apply the binaries based on the platform:

```shell
sudo ./apply_binaries.sh --openrm
```

### 3. Build the kernel compilation environment

#### 3.1 Extracting the Toolchain

Source link: [Jetson Linux Toolchain — NVIDIA Jetson Linux Developer Guide](https://docs.nvidia.com/jetson/archives/r38.2/DeveloperGuide/AT/JetsonLinuxToolchain.html#jetson-linux-toolchain)

```shell
cd <real-dir>/workspaces/nvtools/
wget https://developer.nvidia.com/downloads/embedded/L4T/r38_Release_v2.0/release/x-tools.tbz2
tar -xf x-tools.tbz2
# Setting the CROSS_COMPILE Environment Variable
export CROSS_COMPILE=<real-dir>/workspaces/nvtools/x-tools/aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-
```

#### 3.2 To Manually Download and Expand the Kernel Sources

```shell
cd <real-dir>/workspaces/source
wget https://developer.nvidia.com/downloads/embedded/L4T/r38_Release_v2.1/sources/public_sources.tbz2
tar -xf public_sources.tbz2
mv ./Linux_for_Tegra/source/kernel_src.tbz2 .
mv ./Linux_for_Tegra/source/kernel_oot_modules_src.tbz2 .
mv ./Linux_for_Tegra/source/nvidia_kernel_display_driver_source.tbz2 .
mv ./Linux_for_Tegra/source/nvidia_unified_gpu_display_driver_source.tbz2 .
rm -r Linux_for_Tegra
```

#### 3.3 Extract the kernel and the NVIDIA out-of-tree modules source files

```shell
cd <real-dir>/workspaces/source
mkdir source_workspace && cd source_workspace
tar -xf ../kernel_src.tbz2
tar -xf ../kernel_oot_modules_src.tbz2
tar -xf ../nvidia_kernel_display_driver_source.tbz2
tar -xf ../nvidia_unified_gpu_display_driver_source.tbz2
```

### 4. Loading Y-C28 BSP

```shell
cd <real-dir>/workspaces
mkdir plink_y-c28
git clone https://github.com/plinkAi/Y-C28_AGX-Thor.git --depth=1 plink_y-c28
```

#### 4.1 Copy the carrier board configuration file to the flash environment

```shell
cd <real-dir>/workspaces
cp -r plink_y-c28/Linux_for_Tegra/* ./flash/Linux_for_Tegra/
```

#### 4.2 Copy the kernel patch to the kernel compilation environment

```shell
cd <real-dir>/workspaces
cp -r plink_y-c28/source/* ./source
```

#### 4.3 Compile the kernel

Explanation: Since the default system does not have the Intel wireless network card driver (iwlwifi), it is necessary to compile the kernel before flashing the system.

##### 4.3.1 Import the required environment variables for compiling the kernel

```shell
cd <real-dir>/workspaces/source/source_workspace
export CROSS_COMPILE=<real-dir>/workspaces/nvtools/x-tools/aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-
export KERNEL_HEADERS=$PWD/kernel/kernel-noble
export kernel_name=noble
```

##### 4.3.2 Import the environment variables required for compiling the real-time kernel (optional)

If you don't need to use the real-time kernel, you can skip this step and proceed directly to the next one.

```shell
cd <real-dir>/workspaces/source/source_workspace
./generic_rt_build.sh "enable"
export IGNORE_PREEMPT_RT_PRESENCE=1
echo "CONFIG_NO_HZ_FULL=y" >> ./kernel/kernel-noble/arch/arm64/configs/defconfig
echo "CONFIG_RCU_NOCB_CPU=y" >> ./kernel/kernel-noble/arch/arm64/configs/defconfig
```

##### 4.3.3 Load kernel patch

```shell
cd <real-dir>/workspaces/source/source_workspace
patch -p1 < ../kernel.patch
```

##### 4.3.4 Building the Jetson Linux Kernel and NVIDIA Out-of-Tree Modules

```shell
cd <real-dir>/workspaces/source/source_workspace
make -C kernel
make modules
```

#### 4.4 Install the compiled kernel module and the image

```shell
cd <real-dir>/workspaces/source/source_workspace
export INSTALL_MOD_PATH=<real-dir>/workspaces/flash/Linux_for_Tegra/rootfs
sudo -E make install -C kernel
sudo -E make modules_install
cp kernel/kernel-noble/arch/arm64/boot/Image <real-dir>/workspaces/flash/Linux_for_Tegra/kernel/Image
```

#### 4.5 To update the initramfs

```shell
cd <real-dir>/workspaces/flash/Linux_for_Tegra
sudo ./tools/l4t_update_initrd.sh
```

#### 4.6 Load the firmware for our carrier board

```shell
cd <real-dir>/workspaces/flash/Linux_for_Tegra
# If you only use the standard kernel, execute the following command:
sudo ./plink-ai_thor_tools general
# If the real-time kernel has been compiled and installed, execute the following command:
sudo ./plink-ai_thor_tools real-time
```

### 5 Flash

- Enter the Recovery mode of the device equipped with the AGX Thor module of Y-C28 (press and hold the SW3 button, then supply power to the carrier board. After power supply, release the button). Connect the FP interface (J2, the USB Type-C interface perpendicular to the PCB board) of the Y-C28 carrier board to the USB Type-A interface of the Linux host through a USB Type-C to USB Type-A cable.
- **In Sections 5.2 and 5.3, depending on the kernel you intend to use, simply select one of the commands from the list and perform the flashing process for the specific device model you require. **
- Open a terminal window on your host computer and enter command `lsusb`. The Jetson module is in Force Recovery Mode if you see the message:

```shell
Bus <bbb> Device <ddd>: ID 0955:<nnnn> NVIDIA Corp. APX
```

- \<bbb>: is any three-digit number.
- \<ddd>: is any three-digit number.
- \<nnnn>:  is a four-digit number that represents the type of your Jetson module, Source link: [To Determine Whether the Developer Kit Is in Force Recovery Mode](https://docs.nvidia.com/jetson/archives/r38.2/DeveloperGuide/IN/QuickStart.html#to-determine-whether-the-developer-kit-is-in-force-recovery-mode)

#### 5.1 Skipping oem-config（Optional）

[Source link](https://docs.nvidia.com/jetson/archives/r38.2/DeveloperGuide/SD/FlashingSupport.html#skipping-oem-config)

```shell
cd <real-dir>/workspaces/flash/Linux_for_Tegra
sudo ./tools/l4t_create_default_user.sh -u nvidia -p nvidia --accept-license
```

The script’s usage is:

```shell
Usage:
l4t_create_default_user.sh [-u <username>] [-p <password>] [-a] [-h]
	-u | --username	- If not specified then default will be set to 'nvidia'.
	-p | --password	- If not set then randomized password will be generated.
	-a | --autologin - If specified autologin will be enabled. Default is disabled
	-n | --hostname - If not specified then default will be set to 'tegra-ubuntu'.
	-h | --help - print usage
	     --accept-license - Specified to accept the terms and conditions of EULA
Example:
l4t_create_default_user.sh -u nvidia -p NDZjMWM4
l4t_create_default_user.sh -u ubuntu -a
l4t_create_default_user.sh -n tegra
```

#### 5.2 General Kernel Flash

- Based on the specific model of the device you are using (please contact our sales colleagues for confirmation), execute the corresponding flashing command for this device on your Linux host, and perform the flashing operation for the Jetson device.

##### Y-C28-DEV(With NVIDIA AGX Thor T5000 Module)

```shell
cd <real-dir>/workspaces/flash/Linux_for_Tegra
sudo ./l4t_initrd_flash_plink.sh y-c28-agx-thor-3821-t5000 internal
```

##### 28F1 Complete Machine (Standard Configuration)

```shell
cd <real-dir>/workspaces/flash/Linux_for_Tegra
sudo ./l4t_initrd_flash_plink.sh y-c28-agx-thor-3821-t5000-ipc internal
```

##### 28F1 complete machine is compatible with SFP+ function

```shell
cd <real-dir>/workspaces/flash/Linux_for_Tegra
sudo ./l4t_initrd_flash_plink.sh y-c28-agx-thor-3821-t5000-ipc-sfp internal
```

- Wait for 15-30 minutes (the performance of the Linux host varies, and the time required for the flashing process also differs). After the flashing is completed, you will be able to see the following information in the terminal of the Linux host:

```shell
[flash_bsp_jetson-t264]: start time  = 1763521167.3946621
[flash_bsp_jetson-t264]: end time  = 1763521498.2930012
[flash_bsp_jetson-t264]: Total Time = 330.89833903312683
[flash_bsp_jetson-t264]: Image Flashing took 330.89833903312683
[flash_bsp_jetson-t264]: Flashing finished Successfully!!
/home/cx/flash/38.2/Linux_for_Tegra
Flashing finish
Cleaning up...
```

After the Flash process is completed, the Y-C28 carrier board will be powered off, and then re-powered on to enter the system initialization interface. If the username and password have been preset before performing the flashing operation, it will directly enter the system login interface.

#### 5.3 Real-time Kernel Flash

- Based on the specific model of the device you are using (please contact our sales colleagues for confirmation), execute the corresponding flashing command for this device on your Linux host, and perform the flashing operation for the Jetson device.

##### Y-C28-DEV(With NVIDIA AGX Thor T5000 Module)

```shell
cd <real-dir>/workspaces/flash/Linux_for_Tegra
sudo ./l4t_initrd_flash_plink.sh y-c28-agx-thor-3821-t5000-rt internal
```

##### 28F1 Complete Machine (Standard Configuration)

```shell
cd <real-dir>/workspaces/flash/Linux_for_Tegra
sudo ./l4t_initrd_flash_plink.sh y-c28-agx-thor-3821-t5000-rt-ipc internal
```

##### 28F1 complete machine is compatible with SFP+ function

```shell
cd <real-dir>/workspaces/flash/Linux_for_Tegra
sudo ./l4t_initrd_flash_plink.sh y-c28-agx-thor-3821-t5000-rt-ipc-sfp internal
```

- Wait for 15-30 minutes (the performance of the Linux host varies, and the time required for the flashing process also differs). After the flashing is completed, you will be able to see the following information in the terminal of the Linux host:

```shell
[flash_bsp_jetson-t264]: start time  = 1763521167.3946621
[flash_bsp_jetson-t264]: end time  = 1763521498.2930012
[flash_bsp_jetson-t264]: Total Time = 330.89833903312683
[flash_bsp_jetson-t264]: Image Flashing took 330.89833903312683
[flash_bsp_jetson-t264]: Flashing finished Successfully!!
/home/cx/flash/38.2/Linux_for_Tegra
Flashing finish
Cleaning up...
```

After the Flash process is completed, the Y-C28 carrier board will be powered off, and then re-powered on to enter the system initialization interface. If the username and password have been preset before performing the flashing operation, it will directly enter the system login interface.

