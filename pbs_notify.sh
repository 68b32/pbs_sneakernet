#!/bin/bash
echo "Send notification ($1)..." 1>&2
# Add your command to send notifications to you
if [ $? -eq 0 ]; then
	echo "Notification successfull." 1>&2
else
	echo "Notification failed." 1>&2
fi
