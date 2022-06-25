#!/bin/bash
# Setting variables and function(s)
echo "auto" > /sys/class/drm/card0/device/power_dpm_force_performance_level
echo "auto" > /sys/class/drm/card1/device/power_dpm_force_performance_level

# If the iGPU's load goes above 90% the iGPU performance level will be set to "auto"
# After 1 second it checks if the load has dropped below 34% after switching the performance level
# If it's below the threshold the performance level will be set to "low"
gpu_governor() {
echo 1
if [[ $(cat /sys/class/drm/$IGPU/device/gpu_busy_percent) -gt 90 ]]
then
        echo "auto" > /sys/class/drm/$IGPU/device/power_dpm_force_performance_level
        sleep 1
elif [[ $(cat /sys/class/drm/$IGPU/device/gpu_busy_percent) -lt 34 ]]
then
        echo "low" > /sys/class/drm/$IGPU/device/power_dpm_force_performance_level
fi
}

# Check if CPU Boostclock is enabled -> if yes -> put the performance level of the iGPU to "auto" 
# 				     -> if not -> continue to the gpu_governor function
## Why put the iGPU to the performance level "auto" when the boostclock is enabled?
## When the iGPU is set to "low" the memory clock drops to 400MHz and limits the CPU's performance to about 80% of its actual potential
gpu_cpu_boostclock() {
if [[ $PS_BOOSTCLOCK == 1 && $POWERPROFILE == power-saver ]]
then
        echo "auto" > /sys/class/drm/$IGPU/device/power_dpm_force_performance_level
elif [[ $B_BOOSTCLOCK == 1 && $POWERPROFILE == balanced ]]
then
        echo "auto" > /sys/class/drm/$IGPU/device/power_dpm_force_performance_level
elif [[ $P_BOOSTCLOCK == 1 && $POWERPROFILE == performance ]]
then
        echo "auto" > /sys/class/drm/$IGPU/device/power_dpm_force_performance_level
else
        gpu_governor
	#echo "low" > /sys/class/drm/$IGPU/device/power_dpm_force_performance_level
fi
}

# Manually set gpu to performance level "auto" (if set to 1)
gpu() {
if [[ $(cat /sys/class/drm/$DGPU/device/power/runtime_status) == active ]]
then
	echo "auto" > /sys/class/drm/$IGPU/device/power_dpm_force_performance_level
elif [[ $PS_GPU_PERFORMANCE_MODE == 1 && $POWERPROFILE == power-saver ]]
then
        echo "auto" > /sys/class/drm/$IGPU/device/power_dpm_force_performance_level
elif [[ $B_GPU_PERFORMANCE_MODE == 1 && $POWERPROFILE == balanced ]]
then
        echo "auto" > /sys/class/drm/$IGPU/device/power_dpm_force_performance_level
elif [[ $P_GPU_PERFORMANCE_MODE == 1 && $POWERPROFILE == performance ]]
then
        echo "auto" > /sys/class/drm/$IGPU/device/power_dpm_force_performance_level
else
        gpu_cpu_boostclock
fi
}

##Misc. stuff
# Disable D3cold on nvme ssd
##echo 0 > /sys/bus/pci/devices/0000:04:00.0/d3cold_allowed 
# Mask faulty interrupt
#echo "mask" >  /sys/firmware/acpi/interrupts/gpe19

# integrated/dedicated GPU number
# check your cardX number with "ls /dev/dri"
IGPU=card0
DGPU=card1

# Power-Save profile
PS_A=22000                              # Sustained Power Limit (mW)
PS_B=22000                              # ACTUAL Power Limit    (mW)
PS_C=22000                              # Average Power Limit   (mW)
PS_K=90000                              # VRM EDC Current       (mA)
PS_F=97                                 # Max Tctl              (C)
PS_GOVERNOR=powersave                   # CPUPower governor
PS_DC_AC=power-saving                   # secret power modes (power-saving / max-performance)
PS_BOOSTCLOCK=0                         # enable CPU boost clocks (set 1 for on, 0 for off)
PS_ALLOWEDCPUS=0-15			# How many CPU cores should be active
PS_GPU_PERFORMANCE_MODE=0               # When off the power profile for iGPU is set to LOW and slightly reduces overall system performance

# Balanced profile
B_A=25000
B_B=25000
B_C=25000
B_K=95000
B_F=97
B_GOVERNOR=conservative
B_DC_AC=power-saving
B_BOOSTCLOCK=0
B_ALLOWEDCPUS=0-15
B_GPU_PERFORMANCE_MODE=1

# Performance profile
P_A=50000
P_B=50000
P_C=50000
P_K=110000
P_F=97
P_GOVERNOR=schedutil
P_DC_AC=max-performance
P_BOOSTCLOCK=1
P_ALLOWEDCPUS=0-15
P_GPU_PERFORMANCE_MODE=1

# loop
while :
do
	POWERPROFILE=$(powerprofilesctl get)

	case $POWERPROFILE in
	  power-saver)
		ryzenadj --$PS_DC_AC
		ryzenadj -a $PS_A -b $PS_B -c $PS_C -k $PS_K -f $PS_F
		cpupower frequency-set -g $PS_GOVERNOR
		cpupower frequency-set --max 1.70GHz
		systemctl set-property --runtime -- user.slice AllowedCPUs=$PS_ALLOWEDCPUS
		systemctl set-property --runtime -- system.slice AllowedCPUs=$PS_ALLOWEDCPUS
		systemctl set-property --runtime -- init.scope AllowedCPUs=$PS_ALLOWEDCPUS
		echo 0 > /sys/devices/system/cpu/cpufreq/boost
		gpu
                if [[ $PS_BOOSTCLOCK == 1 ]]
                then
                        echo 1 > /sys/devices/system/cpu/cpufreq/boost
                else
                        echo 0 > /sys/devices/system/cpu/cpufreq/boost
                fi

	    ;;
 	  balanced)
		ryzenadj --$B_DC_AC
		ryzenadj -a $B_A -b $B_B -c $B_C -k $B_K -f $B_F
		cpupower frequency-set -g $B_GOVERNOR
		cpupower frequency-set --max 5GHz
                sudo systemctl set-property --runtime -- user.slice AllowedCPUs=$B_ALLOWEDCPUS
                sudo systemctl set-property --runtime -- system.slice AllowedCPUs=$B_ALLOWEDCPUS
                sudo systemctl set-property --runtime -- init.scope AllowedCPUs=$B_ALLOWEDCPUS
		gpu
               if [[ $B_BOOSTCLOCK == 1 ]]
                then
			echo 1 > /sys/devices/system/cpu/cpufreq/boost
                else
			echo 0 > /sys/devices/system/cpu/cpufreq/boost
		fi
	    ;;
	 performance)
		ryzenadj --$P_DC_AC
		ryzenadj -a $P_A -b $P_B -c $P_C -k $P_K -f $P_F
		cpupower frequency-set -g $P_GOVERNOR
		cpupower frequency-set --max 5GHz
                sudo systemctl set-property --runtime -- user.slice AllowedCPUs=$P_ALLOWEDCPUS
                sudo systemctl set-property --runtime -- system.slice AllowedCPUs=$P_ALLOWEDCPUS
                sudo systemctl set-property --runtime -- init.scope AllowedCPUs=$P_ALLOWEDCPUS
		gpu
                if [[ $P_BOOSTCLOCK == 1 ]]
                then
			echo 1 > /sys/devices/system/cpu/cpufreq/boost
                else
			echo 0 > /sys/devices/system/cpu/cpufreq/boost
		fi
	    ;;
	esac
sleep 6
done
