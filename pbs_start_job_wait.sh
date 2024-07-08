#!/bin/bash

out() {
	echo "$1" 1>&2
	[ -n "$2" ] && exit $2
}

jobtype="$1"
jobid="$2"

echo "$jobtype" | grep -P 'sync|verify|prune' &> /dev/null
[ $? -ne 0 ] && out "Jobtype must be \"sync\", \"verify\" or \"prune\"" 1
[ -z "$jobid" ] && out "No jobid given." 1

echo "Starting job $jobid..."
upid="`proxmox-backup-manager $jobtype-job run $jobid --output-format json-pretty`"


if [ $? -eq 0 ]; then
	upid=`echo $upid | cut -d\" -f2`
	out "Waiting for job $jobid to be finished."
	out "UPID is $upid"
	sleep 5
	while true; do

		tskl="`proxmox-backup-manager task list --output-format json`"

		if [ $? -eq 0 ]; then
			jcnt=`echo $tskl | jq ".[] | select(.upid==\"$upid\")" | wc -l`
			if [ "$jcnt" -eq 0 ]; then
				out "Job finished." 0
			fi
		else
			out "Error getting task list."
		fi
		sleep 15
	done;
else
	out "Starting job $jobid failed." 1
fi
