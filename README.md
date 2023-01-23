# You are doing everything at your OWN risk! I do not hold any liability for any damages done to your hardware!

# Zephyrus G15 Tweaks (2020 model)
Here I just want to share my personal tweaks/scripts that I use on my daily-driver laptop.

I use Arch, btw.

# Applying Kernel parameters
For GRUB users:
When we are setting certain kernel parameters, we put these parameters into the line called `GRUB_CMDLINE_LINUX_DEFAULT=` which is located in the `/etc/default/grub` file.
After we are done setting the parameters we need to regenerate the grub config by typing `sudo grub-mkconfig -o /boot/grub/grub.cfg` into the terminal. Then reboot for the changes to apply.

# NVIDIA GPU D3 power state on Arch Linux
**All of this was tested on KDE Plasma using the Wayland session and SDDM as the Login manager.**

Of course many people probably use the [supergfxctl](https://gitlab.com/asus-linux/supergfxctl) tool to manage their NVIDIA GPU whether you want to disable it or enable it. But it has one big disadvantage, you always have to logout from your current session to actually change to the desired mode.
The thing is that it is possible to use the D3 power state (like in Windows) but it is kinda broken on Linux without some manual tweaking.
Of course big thanks goes to [whyyfu](https://www.reddit.com/user/whyyfu/) from reddit [(post)](https://www.reddit.com/r/Fedora/comments/tnk47g/nvidia_gpu_runtime_d3_with_wayland_on_supported/) for providing the information for making D3 to work in Linux!

This means that you can use the GPU whenever you want but when you for example stop playing a game the GPU will automatically turn it's self off to preserve power, leading to better battery life overall. Which is probably what everyone wants!


**Of course this is done when using the proprietary drivers!**

**And you need at LEAST a Ryzen 4000 series Zen 2 CPU (older have to be tested) and the GPU to be based on Turing!**

**So here are the steps you have to take to make D3 power state work**

1. * Create a file called `nvidia.conf` in `/etc/modprobe.d/` by typing `sudo nano /etc/modprobe.d/nvidia.conf` into terminal and copy/paste `options nvidia "NVreg_DynamicPowerManagement=0x02"` into the file. This enables the power management.
2. * Turn off NVIDIA modeset by putting `nvidia-drm.modeset=0` in the kernel cmdline, and for good measure also `rd.driver.blacklist=nouveau modprobe.blacklist=nouveau`, this will block nouveau from loading.
3. * Run `sudo rm -f /usr/share/glvnd/egl_vendor.d/10_nvidia.json`. This file points to the EGL library, but that file seems to prevent the GPU from going into the D3 power state, so we remove it.
4. * And if you are using any login/display managers that uses Xorg you will have to remove (Please backup these files if anything goes wrong!) any config that points to NVIDIA because that seems to load an Xorg process on the GPU that will always run on it and will prevent the GPU from going into the D3 state. These configs are located in `/etc/X11/` `etc/X11/xorg.conf.d/` and `/usr/share/X11/xorg.conf.d/`. There should be one located in `/usr/share/X11/xorg.conf.d/` named `10-nvidia-drm-outputclass.conf`, so delete it.
5. * Create a new file at `/lib/udev/rules.d/` called `80-nvidia-pm.rules` and copy/paste this into it
```
#Remove NVIDIA USB xHCI Host Controller devices, if present
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", ATTR{remove}="1"

#Remove NVIDIA USB Type-C UCSI devices, if present
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c8000", ATTR{remove}="1"

#Remove NVIDIA Audio devices, if present
ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{remove}="1"

#Enable runtime PM for NVIDIA VGA/3D controller devices on driver bind
ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"

#Disable runtime PM for NVIDIA VGA/3D controller devices on driver unbind
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"
```

* Reboot, ?????, Profit

To check if it worked, run `cat /sys/class/drm/card0/device/power_state` in terminal and it should show D3cold, that means it's off, and should turn on (showing D0) when you run `nvidia-smi` or `nvtop`

To check power draw, run `cat /sys/class/power_supply/BAT0/power_now` in terminal.

**Beware that after each update of the NVIDIA package you will have to repeat steps 3 and 4!**

# CPU/iGPU Tweaks
**Required package is ryzenadj**

I have made a simple script where you can adjust all sorts of values that will change depending on what power profile you will use (Power Save / Balanced / Performance). For example you can choose the maximum power draw of the CPU, enable or disable cpu boost clocks and much more.


To "install" this script you have to put it in the root directory (so the path will be like so: `/power-profiles.sh`).
To have the script started at boot you have to create a systemd service, one way is to copy the `power-profiles.service` file to `/etc/systemd/system/`, then type `sudo systemctl daemon-reload` and `sudo systemctl enable power-profiles --now` in your terminal to enable/start the service.

**Miscellaneous tweaks**

Increasing the shared VRAM for the AMD APU from the default 3GB to 4GB (or more if you want). To increase VRAM you need to add `amdgpu.gttsize=4096` in the kernel cmdline. (Size is in MEGABYTES, so 4096 equals to 4GB)

(Ignore this comment :))
