### Preparation

At debian installation we here used US locale and keyboard, East Coast time zone, set up the admin root with password 12345678 and user control with password 1234.
As software packages we deselected all desktop window managers and selected SSH, so only standard-system utilities and SSH server was selected.

After installation, find out the IP address to connect via ssh user "control" and enter.

``ip a``

The second interface shows your IP, starting usually with 192.168., might be also start with 172 or 10 depending on your environment.
Let's say it's 192.168.42.105 here but since it is given by DHCP from your router we want to ensure it stays the same all the time, so we are going to switch to a static address.
This should be outside of the DHCP pool your router is assigning. My DHCP assigns 192.168.42.100 to 192.168.42.199 so I am going to pick 192.168.42.200 just outside of the area.

For easy copy & paste of commands we now go to connect via ssh from your main machine, if it is windows, you might go and install putty or you can also easily use standart CMD and enter

``ssh control@192.168.42.105`` use your IP and password (see above)

Now we are setting up a static IP address:
Switch to root by entering

``su -``

open /etc/network/interfaces in the editor by

``nano /etc/network/interfaces``

comment out the dhcp line and add your static details below as follows:

``# The primary network interface``

``allow-hotplug enp0s3``

``#iface enp0s3 inet dhcp``

``iface enp0s3 inet static``

 ``address 192.168.42.200``
 
 ``netmask 255.255.255.0``
 
 ``gateway 192.168.42.1 # your router``
 
 ``dns-nameservers 192.168.42.1 # your router or DNS of quad9/cloudflare/google``
 
 ``dns-domain somewhere.lan # your local domain - optional``
     

restart the network
``systemctl restart networking``

If you have been connected with ssh, you get disconnected. Connect to your new IP address now

``ssh control@192.168.42.200`` and control password

We install git

``su`` and root password

``apt update``

``apt install -y git``

``exit``

If you are using Debian 13 we need to break it a little bit, this does not apply to Debian 12

``su``

``nano /etc/apt/sources.list``

Add following at the end:

``# Unstable``

``deb https://deb.debian.org/debian/ unstable main contrib non-free``

``deb-src https://deb.debian.org/debian/ unstable main contrib non-free``


Save & close. (CTRL+X) + Y

``nano /etc/apt/preferences``

Add following:

``Package: *``

``Pin: release a=unstable``

``Pin-Priority: -1000``

Save & close.

Run:

``apt update && apt-get -t unstable install software-properties-common``

``apt-add-repository non-free``

``dpkg --add-architecture i386``

``apt update``

``exit``

If you are for some reason using Debian 12 you can directly do

``su``

``apt install software-properties-common``

``apt-add-repository non-free``

``dpkg --add-architecture i386``

``apt update``

``exit``

Now you are prepared to run the rest by script!

Download the installation script:

``git clone https://github.com/lennoknet/vein-server.git``

``cd vein-server``

``chmod +x setup-vein-server.sh``

``su`` and root password

``./setup-vein-server.sh``

Follow instructions on your screen.
