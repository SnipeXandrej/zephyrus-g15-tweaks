#!/bin/bash
# Setting variables and function(s)

# A > Sustained Power Limit (mW)
# B > ACTUAL Power Limit    (mW)
# C > Average Power Limit   (mW)
# K > VRM EDC Current       (mA)
# F > Max Tctl              (C)
# GOVERNOR > CPUPower governor (Check them with "cat cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors")
# DC_AC > secret power modes (power-saving / max-performance)
# BOOSTCLOCK > enable CPU boost clocks (set 1 for on, 0 for off)
# ALLOWEDCPUS > How many CPU cores should be active
# CPU_MAX_FREQ > Specify the highest frequency the CPU should run at (Check them with "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies")
# GPU_PERFORMANCE_MODE > When off the power profile for iGPU is set to LOW and slightly reduces overall system performance

# Power-Save profile
PS_A=65000
PS_B=22000
PS_C=65000
PS_K=90000
PS_F=97
PS_GOVERNOR=conservative
PS_DC_AC=power-saving
PS_BOOSTCLOCK=0
PS_ALLOWEDCPUS=0-15
PS_CPU_MAX_FREQ=1400000
PS_GPU_PERFORMANCE_MODE=0

# Balanced profile
B_A=65000
B_B=20000
B_C=65000
B_K=90000
B_F=97
B_GOVERNOR=conservative
B_DC_AC=max-performance
B_BOOSTCLOCK=0
B_ALLOWEDCPUS=0-15
B_CPU_MAX_FREQ=3000000
B_GPU_PERFORMANCE_MODE=1

# Performance profile
P_A=65000
P_B=35000
P_C=65000
P_K=110000
P_F=97
P_GOVERNOR=schedutil
P_DC_AC=max-performance
P_BOOSTCLOCK=1
P_ALLOWEDCPUS=0-15
P_CPU_MAX_FREQ=3000000
P_GPU_PERFORMANCE_MODE=1

# integrated/dedicated GPU number
# check your cardX number with "ls /dev/dri"
IGPU=card0
DGPU=card1

echo "auto" > /sys/class/drm/$IGPU/device/power_dpm_force_performance_level

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

# loop
while :
do
	POWERPROFILE=$(powerprofilesctl get)

	case $POWERPROFILE in
	  power-saver)
		ryzenadj --$PS_DC_AC
		ryzenadj -a $PS_A -b $PS_B -c $PS_C -k $PS_K -f $PS_F
		echo $PS_GOVERNOR | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
		echo $PS_CPU_MAX_FREQ | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq
		systemctl set-property --runtime -- user.slice AllowedCPUs=$PS_ALLOWEDCPUS
		systemctl set-property --runtime -- system.slice AllowedCPUs=$PS_ALLOWEDCPUS
		systemctl set-property --runtime -- init.scope AllowedCPUs=$PS_ALLOWEDCPUS
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
		echo $B_GOVERNOR | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
		echo $B_CPU_MAX_FREQ | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq
		systemctl set-property --runtime -- user.slice AllowedCPUs=$B_ALLOWEDCPUS
		systemctl set-property --runtime -- system.slice AllowedCPUs=$B_ALLOWEDCPUS
		systemctl set-property --runtime -- init.scope AllowedCPUs=$B_ALLOWEDCPUS
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
		echo $P_GOVERNOR | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
		echo $P_CPU_MAX_FREQ | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq
		systemctl set-property --runtime -- user.slice AllowedCPUs=$P_ALLOWEDCPUS
		systemctl set-property --runtime -- system.slice AllowedCPUs=$P_ALLOWEDCPUS
		systemctl set-property --runtime -- init.scope AllowedCPUs=$P_ALLOWEDCPUS
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
