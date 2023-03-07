#!/bin/bash


###################################################################################################################
# Name: pmxcfs-ram.sh
# Description: pmxcfs-ram is a script that can significantly reduce or even
# eliminate the I/O operations of pmxcfs process by storing its data in RAM instead of
# on your HDD/SSD
# Author: Agustin Santiago Isasmendi
# Email: isasmendi.agus@gmail.com
#
# License:
# MIT License
#
# Copyright (c) 2023
# Agustin Santiago Isasmendi
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
###################################################################################################################



###################################################################################################################
# NAME OF THE PROXMOX CLUSTER SERVICE
PVE_CLUSTER_SERVICE_NAME="pve-cluster.service"
#
# PROXMOX DIRECTORY PATH
VARLIBDIR_PATH="/var/lib/pve-cluster" # Path to the Proxmox directory. For more information, see https://github.com/proxmox/pve-cluster/blob/master/data/src/cfs-utils.h#L34
#
# PROXMOX DIRECTORY IN RAM PATH
VARLIBDIR_RAM_PATH="/dev/shm/pve-cluster-ram" # Path to the Proxmox directory stored in RAM.
#
# PERSISTENCY PATH
# When the service is shut down or when the timeout specified by PERSISTENCY_TIMEOUT is reached, the data stored in RAM is written to disk at the location specified below.
# Only modify this location before starting the service for the first time!
VARLIBDIR_PERSISTENT_PATH="/var/lib/pve-cluster-persistent"
#
# PERSISTENCY TIMEOUT IN SECONDS
# After this amount of time (specified in seconds), the data stored in RAM will be written to disk.
# If you want to persist the PVE config only at shutdown time, set this option to 0
PERSISTENCY_TIMEOUT=3600
#
###################################################################################################################




#Boolean constants
TRUE=1
FALSE=0


function is_mounted () {
	local IS_MOUNTED=$(awk '$2 == '\""$1"\"\ '{print $2}' /proc/mounts)

	if [[ ! -z "$IS_MOUNTED" ]] ; then
		echo TRUE
	fi
	echo FALSE
}

function is_service_running () {
	# Check if the specified service is already running
 	systemctl is-active --quiet "$1" && echo TRUE || echo FALSE
}

function activate_service () {
	# Notify systemd that the service is ready
	systemd-notify --ready --status="PMXCFS RAM Service started"
}


function persist_data () {
	#Write data stored in RAM to disk
	rm "$VARLIBDIR_PERSISTENT_PATH"/*
	cp -r "$VARLIBDIR_RAM_PATH"/* "$VARLIBDIR_PERSISTENT_PATH"
}


function run_loop() {
	# Main loop that checks if data needs to be persisted
	while true
	do
		if [[ $PERSISTENCY_TIMEOUT -gt 0 ]] ; then
        	sleep "$PERSISTENCY_TIMEOUT" &
           	wait
			persist_data
		else
			sleep 10 &
			wait
		fi
	done
}



function start () {

	mount=$(is_mounted "$VARLIBDIR")
	cluster_running=$(is_service_running "$PVE_CLUSTER_SERVICE_NAME")

	echo "Checking conditions to start the service"
	if [[ $mount == TRUE ]] ; then
		echo "Cannot start service, "$VARLIBDIR" already mounted. Exit"
		exit 1
	fi

	if [[ $cluster_running == TRUE ]] ; then
		echo "Cannot start service, "$PVE_CLUSTER_SERVICE_NAME" already running. Exit"
		exit 1
	fi

	if [[ -d $VARLIBDIR_RAM_PATH ]] ; then
		echo "Temporal path in memory already exist, cannot start service. Exit"
		exit 1
	fi


	# This section of code is executed only first time running the script.
	# It takes the current PVE configuration and copy to $VARLIBDIR_PERSISTENT_PATH
	if [[ ! -d $VARLIBDIR_PERSISTENT_PATH ]] ; then
		echo "First time running the service, creating persistent folder with current PVE configuration"
		mkdir -p "$VARLIBDIR_PERSISTENT_PATH" || exit 1
		cp -r "$VARLIBDIR_PATH"/* "$VARLIBDIR_PERSISTENT_PATH" || exit 1
	fi


	echo "Creating folder in RAM"
	mkdir "$VARLIBDIR_RAM_PATH" || ( echo "Cannot create in RAM directory. Exit" ; exit 1)

	echo "Copying PVE config from "$VARLIBDIR_PERSISTENT_PATH" to RAM"
	cp -r "$VARLIBDIR_PERSISTENT_PATH"/* "$VARLIBDIR_RAM_PATH"

	echo "Mounting RAM folder to $VARLIBDIR_PATH"
	#After this point Proxmox will write to $VARLIBDIR_PATH but actually this path is mounted to $VARLIBDIR_RAM_PATH (in memory)
	mount --bind "$VARLIBDIR_RAM_PATH" "$VARLIBDIR_PATH" || ( echo "Cannot mount directory. Exit" ; exit 1 )

	#Set service as active. This will allow the service pve-cluster.service to be launched.
	#See directive Before=pve-cluster.service in file /etc/systemd/system/pmxcfs-ram.service
	activate_service

	#Since pmxcfs-ram.service is a service Type=Notify. The main process is the daemon itself.
	run_loop

	}


function stop () {

	#Save latest data
	persist_data

	#Stop myself and the loop
	exit 0

}


trap stop SIGTERM
start

