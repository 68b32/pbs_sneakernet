#!/bin/bash

out() {
	echo "$1" 1>&2
	[ -n "$2" ] && exit $2
}

datastore="$1"
ds_mnt_unit="mnt-datastore-$datastore.mount"


# Check current mount status
systemctl status $ds_mnt_unit &> /dev/null
[ $? -ne 0 ] && out "Datastore mount unit $ds_mnt_unit not active. Aborting." $?


# Wait for no tasks running
out "Waiting for no tasks to run..."
while true; do
	task_count=`proxmox-backup-manager task list --output-format json | jq length`
	if [ "$task_count" -eq "0" ]; then
		out "No tasks running"
		break;
	else
		sleep 60
	fi
done;


# Stop PMS services and unmount datastore
out "Stopping PBS services..."
systemctl stop proxmox-backup.service proxmox-backup-proxy.service
if [ $? -eq 0 ]; then
	out "Stopping services successful."

	out "Unmounting datastore $datastore (Unit $ds_mnt_unit)..."
	systemctl stop $ds_mnt_unit
	if [ $? -ne 0 ]; then
		out "Stopping unit $ds_mnt_unit failed."
	else
		out "Unmounting datastore successful."
	fi
else
	out "Stopping services failed."
fi

out "Restarting PBS services..."
systemctl restart proxmox-backup.service proxmox-backup-proxy.service

if [ $? -ne 0 ]; then
	out "Restarting services failed." 1
else
	out "Restarting services successful." 0
fi
