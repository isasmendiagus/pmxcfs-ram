# Introduction
pmxcfs-ram is a service that can significantly reduce or even eliminate the I/O operations of pmxcfs by storing its data in RAM instead of on your HDD/SSD. 
It's crucial to note that using this service comes with a risk. If your system experiences a sudden shutdown, you may lose the latest changes made to the PVE configuration when using this service. 

# How It Works

The pmxcfs-ram service creates a folder in RAM and mounts it (`mount --bind`) over the directory that pmxcfs uses for its operation (`/var/lib/pve-cluster`). To ensure data persistence, the service saves RAM data to the disk in the directory /var/lib/pve-cluster-persistent at certain intervals. You can configure or disable this feature as needed.

When you shut down your system correctly, the service copies the latest changes in RAM to your disk. 
At system startup, the pmxcfs-ram service retrieves the configuration from the `/var/lib/pve-cluster-persistent` directory and copies it to memory. It then mounts the folder in RAM over the directory that pmxcfs uses for its operation (`/var/lib/pve-cluster`), ensuring that the pmxcfs process remains unaware that it's writing to memory.

# Installation:

1 - First, create a backup of your current configuration in case something goes wrong.
```
$ sudo systemctl stop pve-cluster.service
$ sudo cp /var/lib/pve-cluster/config.db <your_safe_folder>
```

It's important to keep this backup secure as it contains the certificates of your Proxmox web interface and other sensitive information. To see what information this file contains, read here: https://pve.proxmox.com/wiki/Proxmox_Cluster_File_System_(pmxcfs)#:~:text=/etc/pve-,Files,-authkey.pub

2 - Create the unit file for the service. 
Run the command and then paste the content of the file .service inside the text editor, save and quit 
```
$ sudo systemctl edit --force --full pmxcfs-ram.service
```

3 - Copy the .sh script to the /usr/bin directory and give execute permissions.
```
$ sudo cp pmxcfs-ram.sh /usr/bin
$ sudo chmod +x /usr/bin/pmxcfs-ram.sh
```

4 - Finally, reload the systemd daemon, enable the new service, and restart your system.
```
$ sudo systemctl daemon-reload
$ sudo systemctl enable pmxcfs-ram.service
$ reboot
```

From this point on, the pmxcfs process will start storing configurations in memory. The script runs in the background and persists the PVE configuration to disk every $PERSISTENCY_TIMEOUT seconds. You can configure this value in the `/usr/bin/pmxcfs-ram.sh` script.

It's important to note that you can't start or stop the pmxcfs-ram.service on demand. Instead, pmxcfs-ram is set up to automatically start before `pve-cluster.service` on system startup and stop after pve-cluster stops on system shutdown.


# Uninstall:

To uninstall the service, you will need to manually copy the currently active PVE configuration in RAM to the directory where pmxcfs works by default, which is /var/lib/pve-cluster.

1 - Stop the pve-cluster.service
```
$ sudo systemctl stop pve-cluster.service
```

2 - Copy the file /var/lib/pve-cluster/config.db to a directory of your choice, for example your home directory ~/ (This file is currently in RAM since pmxcfs-ram is running)
```
$ sudo cp /var/lib/pve-cluster/config.db ~/
```

3 - Enable pve-cluster.service
```
$ sudo systemctl start pve-cluster.service
```

4 - Disable pmxcfs-ram.service from your system and then reboot
```
$ sudo systemctl disable pmxcfs-ram.service && sudo reboot
```

5 - Stop the pve-cluster.service
```
$ sudo systemctl stop pve-cluster.service
```

6 - Restore your configuration
```
$ sudo cp ~/config.db /var/lib/pve-cluster/config.db
```
7 - Start the pve-cluster service again
```
$ sudo systemctl start pve-cluster.service
```

