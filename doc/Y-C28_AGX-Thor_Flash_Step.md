# Y-C28搭载Jetson AGX Thor系列模组刷机说明

##  前提条件

- 独立的X86架构的Linux主机；
- Linux主机预装Ubuntu22.04的操作系统；
- USB Type-A 转 USB Type-C 的线缆（支持数据传输）；

## 使用说明

- \<real-time>代表您用来刷机的实际路径，注意：绝对路径不能存在中文目录（绝对路径中不能存在中文）；

  文档中每个代码段的第一行命令都是确保进入到该代码段后续命令执行所在的路径；

### 1、创建工作目录

```shell
mkdir <real-dir>/workspaces && cd <real-dir>/workspaces
mkdir flash nvtools source
```

### 2、构建Flash刷机环境

#### 2.1、下载NVIDIA Jetson Linux for Tegra驱动

```shell
cd <real-dir>/workspaces/flash
wget https://developer.nvidia.com/downloads/embedded/L4T/r38_Release_v2.1/release/Jetson_Linux_R38.2.1_aarch64.tbz2
tar -xf Jetson_Linux_R38.2.1_aarch64.tbz2
```

#### 2.2、下载NVIDIA Jetson Linux for Tegra 示例根文件系统包

```shell
cd <real-dir>/workspaces/flash
wget https://developer.nvidia.com/downloads/embedded/L4T/r38_Release_v2.1/release/Tegra_Linux_Sample-Root-Filesystem_R38.2.1_aarch64.tbz2
sudo tar -xpf Tegra_Linux_Sample-Root-Filesystem_R38.2.1_aarch64.tbz2 -C Linux_for_Tegra/rootfs/
```

#### 2.3、安装Flash环境所必须的依赖

注意：安装依赖建议使用Ubuntu系统自带的APT软件源，其他软件源可能存在缺少部分依赖软件

```shell
cd <real-dir>/workspaces/flash/Linux_for_Tegra
sudo ./tools/l4t_flash_prerequisites.sh
```

#### 2.4、对根文件系统应用必要的更改：

```shell
sudo ./apply_binaries.sh --openrm
```

### 3、构建内核编译环境

#### 3.1、构建交叉编译环境

```shell
cd <real-dir>/workspaces/nvtools/
wget https://developer.nvidia.com/downloads/embedded/L4T/r38_Release_v2.0/release/x-tools.tbz2
tar -xf x-tools.tbz2
export CROSS_COMPILE=<real-dir>/workspaces/nvtools/x-tools/aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-
```

#### 3.2、下载NVIDIA Jetson L4T驱动源码包

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

#### 3.3、构建源码编译环境

```shell
cd <real-dir>/workspaces/source
mkdir source_workspace && cd source_workspace
tar -xf ../kernel_src.tbz2
tar -xf ../kernel_oot_modules_src.tbz2
tar -xf ../nvidia_kernel_display_driver_source.tbz2
tar -xf ../nvidia_unified_gpu_display_driver_source.tbz2
```

### 4、加载本公司自研载板板级支持包（BSP）

```shell
cd <real-dir>/workspaces
mkdir plink_y-c28
git clone https://gitee.com/plink718/Y-C28_AGX-Thor.git --depth=1 plink_y-c28
```

#### 4.1、将载板配置文件拷贝到刷机环境

```shell
cd <real-dir>/workspaces
cp -r plink_y-c28/Linux_for_Tegra/* ./flash/Linux_for_Tegra/
```

#### 4.2、将内核补丁拷贝到内核编译环境

```shell
cd <real-dir>/workspaces
cp -r plink_y-c28/source/* ./source
```

#### 4.3、编译内核

说明：由于默认系统没有 Intel 无线网卡驱动（iwlwifi），所以在刷机前需要编译内核；

##### 4.3.1、导入编译内核所需环境变量

```shell
cd <real-dir>/workspaces/source/source_workspace
export CROSS_COMPILE=<real-dir>/workspaces/nvtools/x-tools/aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-
export KERNEL_HEADERS=$PWD/kernel/kernel-noble
export kernel_name=noble
```

##### 4.3.2、导入编译实时内核所需环境变量（可选）

如果不需要使用实时内核，可以跳过当前步骤，直接执行下一步

```shell
cd <real-dir>/workspaces/source/source_workspace
./generic_rt_build.sh "enable"
export IGNORE_PREEMPT_RT_PRESENCE=1
echo "CONFIG_NO_HZ_FULL=y" >> ./kernel/kernel-noble/arch/arm64/configs/defconfig
echo "CONFIG_RCU_NOCB_CPU=y" >> ./kernel/kernel-noble/arch/arm64/configs/defconfig
```

##### 4.3.3、生效内核补丁

```shell
cd <real-dir>/workspaces/source/source_workspace
patch -p1 < ../kernel.patch
```

##### 4.3.4、编译内核以及外部模块

```shell
cd <real-dir>/workspaces/source/source_workspace
make -C kernel
make modules
```

#### 4.4、安装编译好的内核模块以及镜像

```shell
cd <real-dir>/workspaces/source/source_workspace
export INSTALL_MOD_PATH=<real-dir>/workspaces/flash/Linux_for_Tegra/rootfs
sudo -E make install -C kernel
sudo -E make modules_install
cp kernel/kernel-noble/arch/arm64/boot/Image <real-dir>/workspaces/flash/Linux_for_Tegra/kernel/Image
```

#### 4.5、更新initramfs

```shell
cd <real-dir>/workspaces/flash/Linux_for_Tegra
sudo ./tools/l4t_update_initrd.sh
```

#### 4.6、生效本公司自研载板板级支持包

```shell
cd <real-dir>/workspaces/flash/Linux_for_Tegra
# 如果只使用普通内核，执行下述命令：
sudo ./plink-ai_thor_tools general
# 如果编译并且安装了实时内核，执行下述命令：
sudo ./plink-ai_thor_tools real-time
```

### 5、刷机

- 将 Y-C28 搭载 AGX Thor模组的设备进入 Recovery 模式（按住SW3按钮，再给载板供电，供电之后，松开按钮即可），并通过 USB Type-C 转 USB Type-A 的线缆，将 Y-C28 载板的FP接口（J2，垂直于PCB板的USB Type-C接口）连接到Linux主机的 USB Type-A 接口。
- 在主机端执行 lsusb 命令将看到下述信息表示设备成功进入Recovery模式。
- **5.2节跟5.3节根据您所需要使用的内核，具体的设备型号选择其中一个命令进行刷机即可。**

```shell
Bus <bbb> Device <ddd>: ID 0955:<nnnn> NVIDIA Corp. APX
```

- \<bbb>：是任意的三位数字
- \<ddd>：是任意的三位数字
- \<nnnn>：是一个四位数字，代表Jetson模块的类型，详情可参考链接：[判断Jetson设备是否处于Recovery模式](https://docs.nvidia.com/jetson/archives/r38.2/DeveloperGuide/IN/QuickStart.html#to-determine-whether-the-developer-kit-is-in-force-recovery-mode)

#### 5.1、使用NVIDIA官方工具预设置用户名密码（可选）

```shell
cd <real-dir>/workspaces/flash/Linux_for_Tegra
sudo ./tools/l4t_create_default_user.sh -u nvidia -p nvidia --accept-license
```

该脚本的具体用法说明如下：

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

#### 5.2、普通内核刷机

- 根据你所使用的具体设备型号（可联系本公司销售同事进行确认），在你的Linux主机上执行该设备对应的刷机命令，为Jetson设备进行刷机：

##### Y-C28-DEV(搭配 NVIDIA AGX Thor T5000模组)

```shell
cd <real-dir>/workspaces/flash/Linux_for_Tegra
sudo ./l4t_initrd_flash_plink.sh y-c28-agx-thor-3821-t5000 internal
```

##### 28F1整机（标准配置）

```shell
cd <real-dir>/workspaces/flash/Linux_for_Tegra
sudo ./l4t_initrd_flash_plink.sh y-c28-agx-thor-3821-t5000-ipc internal
```

##### 28F1整机适配 **SFP+** 功能

```shell
cd <real-dir>/workspaces/flash/Linux_for_Tegra
sudo ./l4t_initrd_flash_plink.sh y-c28-agx-thor-3821-t5000-ipc-sfp internal
```

- 等待 15-30分钟（Linux主机的性能不同，所需要的刷机时间也是不同的）刷机结束之后，能够在Linux主机的终端看到如下信息：

```
[flash_bsp_jetson-t264]: start time  = 1763521167.3946621
[flash_bsp_jetson-t264]: end time  = 1763521498.2930012
[flash_bsp_jetson-t264]: Total Time = 330.89833903312683
[flash_bsp_jetson-t264]: Image Flashing took 330.89833903312683
[flash_bsp_jetson-t264]: Flashing finished Successfully!!
/home/cx/flash/38.2/Linux_for_Tegra
Flashing finish
Cleaning up...
```

之后将Y-C28载板断电，然后重新上电即可进入到系统初始化界面。如果在执行刷机之前预设置过用户名密码，则会直接进入到系统登录界面。

#### 5.3、实时内核刷机

- 根据你所使用的具体设备型号（可联系本公司销售同事进行确认），在你的Linux主机上执行该设备对应的刷机命令，为Jetson设备进行刷机：

##### Y-C28-DEV(搭配 NVIDIA AGX Thor T5000模组)

```shell
cd <real-dir>/workspaces/flash/Linux_for_Tegra
sudo ./l4t_initrd_flash_plink.sh y-c28-agx-thor-3821-t5000-rt internal
```

##### 28F1整机（标准配置）

```shell
cd <real-dir>/workspaces/flash/Linux_for_Tegra
sudo ./l4t_initrd_flash_plink.sh y-c28-agx-thor-3821-t5000-rt-ipc internal
```

##### 28F1整机适配 **SFP+** 功能

```shell
cd <real-dir>/workspaces/flash/Linux_for_Tegra
sudo ./l4t_initrd_flash_plink.sh y-c28-agx-thor-3821-t5000-rt-ipc-sfp internal
```

- 等待 15-30分钟（Linux主机的性能不同，所需要的刷机时间也是不同的）刷机结束之后，能够在Linux主机的终端看到如下信息：

```
[flash_bsp_jetson-t264]: start time  = 1763521167.3946621
[flash_bsp_jetson-t264]: end time  = 1763521498.2930012
[flash_bsp_jetson-t264]: Total Time = 330.89833903312683
[flash_bsp_jetson-t264]: Image Flashing took 330.89833903312683
[flash_bsp_jetson-t264]: Flashing finished Successfully!!
/home/cx/flash/38.2/Linux_for_Tegra
Flashing finish
Cleaning up...
```

之后将Y-C28载板断电，然后重新上电即可进入到系统初始化界面。如果在执行刷机之前预设置过用户名密码，则会直接进入到系统登录界面。

