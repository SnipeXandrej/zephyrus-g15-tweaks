#!/bin/bash
echo "auto" > /sys/class/drm/card1/device/power_dpm_force_performance_level
sleep 1

while :
do
	while [[ $(cat /sys/class/drm/card0/device/power/runtime_status) == active ]]
	do
		echo "auto" > /sys/class/drm/card1/device/power_dpm_force_performance_level
		sleep 1
	done

		if [[ $(cat /sys/class/drm/card1/device/gpu_busy_percent) -gt 90 ]]
		then
			while [ $(cat /sys/class/drm/card1/device/gpu_busy_percent) -gt 34 ]
			do
				echo "high" > /sys/class/drm/card1/device/power_dpm_force_performance_level
				sleep 1
			done
		else
			echo "low" > /sys/class/drm/card1/device/power_dpm_force_performance_level
		fi
sleep 1
done
