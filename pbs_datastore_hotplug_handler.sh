#!/bin/bash

configdir="/etc/pbs_datastore_hotplug_handler"

check_config() {
	colons="`echo \"$1\" | grep -o \":\" | wc -l`"
	[ "$colons" -eq 5 ] && return 0
	return 1
}

if [ "$#" -ne 1 ]; then
	echo "No arguments given." 1>&2
	exit 1
fi


config="$1"
if ! check_config "$config"; then
	echo "Config read from argument not valid. ($config)" 1>&2
	echo "Reading from $configdir" 1>&2

	serial="`udevadm info --query=all --name=/dev/$1 2> /dev/null | grep ID_SERIAL_SHORT | cut -d= -f2`";

	if [ -z "$serial" ]; then
		echo "Could not get ID_SERIAL_SHORT with argument $1. (/dev/$1)"  1>&2
		exit 1
	fi


	if [ -s "$configdir/$serial" ]; then
		config="`cat \"$configdir/$serial\"`"
		if ! check_config "$config"; then
			echo "Error reading config from file $configdir/$serial" 1>&2
			exit 1
		fi
	else
		echo "Could not read configuration from $configdir/$serial" 1>&2
		exit 1
	fi
fi


echo "Used configuration string is $config" 1>&2

datastore="`echo $config | cut -d: -f1`"
syncjob="`echo $config | cut -d: -f2`"
verifyjob="`echo $config | cut -d: -f3`"
prunejob="`echo $config | cut -d: -f4`"
device="`echo $config | cut -d: -f5`"
gc_on_percent="`echo $config | cut -d: -f6`"

echo "DS: $datastore" 1>&2;
echo "SJ: $syncjob" 1>&2
echo "VJ: $verifyjob" 1>&2
echo "PJ: $prunejob" 1>&2
echo "DV: $device" 1>&2


ds_mnt_unit="mnt-datastore-$datastore.mount"
device_name="/dev/$device"

pbs_alarm.sh
pbs_notify.sh "Start offsite $datastore"

systemctl start $ds_mnt_unit && \
pbs_start_job_wait.sh sync $syncjob

if [ $? -ne 0 ]; then
	echo "Sync failed." 1>&2
	pbs_notify.sh "Offsite $datastore SYNC failed."
	exit 1
fi

get_usage() {
	dfh="`df -h | grep $device_name`";
	df_used="`echo $dfh | awk '{print $3}'`";
	df_all="`echo $dfh | awk '{print $2}'`";
	df_usedp="`echo $dfh | awk '{print $5}' | grep -Po '[0-9]+'`";
}

get_usage;

echo "Used space is $df_used of $df_all ($df_usedp)."

if [ "$df_usedp" -ge "$gc_on_percent" ]; then

	echo "Start prune and GC." 1>&2
	pbs_notify.sh "Start prune and GC for $datastore ($df_used / $df_all / $df_usedp%)."

	pbs_start_job_wait.sh prune $prunejob && \
	proxmox-backup-manager garbage-collection start $datastore

	if [ $? -eq 0 ]; then
		get_usage;
		echo "Prune and GC done ($df_used / $df_all / $df_usedp%)."
	else
		echo "Prune and GC failed." 1>&2
		pbs_notify.sh "Offsite $datastore PRUNE and GC failed."
		exit 1
	fi
fi

pbs_start_job_wait.sh verify $verifyjob && \
pbs_unmount_datastore.sh $datastore

if [ $? -eq "0" ]; then
	pbs_notify.sh "Offsite $datastore done ($df_used / $df_all / $df_usedp%)."
else
	pbs_notify.sh "Offsite $datastore failed."
fi

echo "Finished." 1>&2
