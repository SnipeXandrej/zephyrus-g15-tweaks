#!/bin/bash
while :
do
ENABLEBOOST=$(cat /home/systemd-scripts/cpu-boost-enableboost)
BATTERY=$(cat /sys/class/power_supply/BAT0/status)
	if [[ $BATTERY == 'Discharging' ]]
	then
		echo 0 > /sys/devices/system/cpu/cpufreq/boost
		cpupower frequency-set -g conservative
	elif [[ $BATTERY == 'Not charging' && $ENABLEBOOST == '1' ]]
	then
		echo 1 > /sys/devices/system/cpu/cpufreq/boost
		cpupower frequency-set -g schedutil
	elif [[ $BATTERY == 'Not charging' && $ENABLEBOOST == '0' ]]
	then
		echo 0 > /sys/devices/system/cpu/cpufreq/boost
		cpupower frequency-set -g conservative
	elif [[ $BATTERY == 'Charging' && $ENABLEBOOST == '1' ]]
	then
		echo 1 > /sys/devices/system/cpu/cpufreq/boost
		cpupower frequency-set -g schedutil
	elif [[ $BATTERY == 'Charging' && $ENABLEBOOST == '0' ]]
	then
		echo 0 > /sys/devices/system/cpu/cpufreq/boost
		cpupower frequency-set -g conservative
	fi
sleep 3
done
