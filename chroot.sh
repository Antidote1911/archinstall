#!/bin/bash
#

set -e

# Globals
user_name=""
user_pw=""
root_pw=""
host_name=""
vm_setting=""
pacman_options="--noconfirm --needed"
yay_options="--quiet --noconfirm --nopgpfetch --mflags --skipinteg"
red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

function real_or_vm() {
	echo "${red}***********************************"
	echo "Type d'installation"
	echo "***********************************${reset}"
	echo
	echo "Machine virtuelle ?"
	read -p "0 - oui, 1 - non: " vm_setting
}

function set_root_pw() {
	echo "${red}***********************************"
	echo "Root Password"
	echo "***********************************${reset}"
	echo
	pass_ok=0
	while [ $pass_ok -eq 0 ]; do
		echo
		echo -n "Set password for root: "
		read root_pw
		echo -n "Confirm password for root: "
		read root_pw_conf
		if [ "$root_pw" = "$root_pw_conf" ]; then
			pass_ok=1
		else
			echo
			echo "Password does not match."
			echo
		fi
	done
	echo "root:${root_pw}" | chpasswd
	echo
	echo
}

function set_hostname() {
	echo "${red}***********************************"
	echo "Hostname Configuration"
	echo "***********************************${reset}"
	echo archlinux > /etc/hostname
	echo '127.0.0.1 archlinux.localdomain archlinux' >> /etc/hosts
	echo
	echo
}

# Create user
function create_user() {
	echo "${red}***********************************"
	echo "User Creation"
	echo "***********************************${reset}"
	echo
	echo -n "Enter desired username: "
	read user_name
	echo
	useradd -m -G adm,audio,floppy,log,network,rfkill,scanner,storage,optical,power,wheel -s /bin/bash $user_name
	echo $'\n'

	pass_ok=0
	while [ $pass_ok -eq 0 ]; do
		echo
		echo -n "Set password for $user_name: "
		read user_pw
		echo -n "Confirm password for $user_name: "
		read user_pw_conf
		if [ "$user_pw" = "$user_pw_conf" ]; then
			pass_ok=1
		else
			echo
			echo "Password does not match."
			echo
		fi
	done
	echo "${user_name}:${user_pw}" | chpasswd
	echo

	# Uncomment %wheel ALL=(ALL) NOPASSWD: ALL to allow members
	# of group wheel to execute any command without a password
	sed -i 's/\# \%wheel ALL=(ALL) NOPASSWD: ALL/\%wheel ALL=(ALL) NOPASSWD: ALL/g' /etc/sudoers

	# And unable  password feedback
	echo "" >> /etc/sudoers
	echo "## Enable password feedback" >> /etc/sudoers
	echo "Defaults env_reset,pwfeedback" >> /etc/sudoers
	echo
	echo
}

function set_timezone() {
	echo "${red}***********************************"
	echo "Locale and Timezone"
	echo "***********************************${reset}"
	echo

	# Set locale, symlink to local time
	ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
	sed -i  '/fr_FR.UTF-8/ s/^#//' /etc/locale.gen
	locale-gen
	echo LANG="fr_FR.UTF-8" > /etc/locale.conf
	export LANG=fr_FR.UTF-8
	echo KEYMAP=fr > /etc/vconsole.conf
	hwclock --systohc --utc
	mkinitcpio -p linux
	echo
	echo
}

function install_packages() {
	echo "${red}***********************************"
	echo "Package Installation"
	echo "***********************************${reset}"
	echo
        # Install packages
	pacman -Syu - < desktop_pkg.txt $pacman_options

	# video drivers
	if [[ $vm_setting == 0 ]]; then
  	echo "${green}Installation des paquets pour la machine virtuelle${reset}"
  	pacman -S virtualbox-guest-utils virtualbox-guest-dkms open-vm-tools $pacman_options
  	systemctl enable vboxservice vmtoolsd.service vmware-vmblock-fuse.service

	elif [[ $vm_setting == 1 ]]; then
  	echo "${green}Installation des paquets pour la machine réelle${reset}"
  	pacman -S xf86-video-amdgpu  vulkan-radeon mesa-libgl mesa-vdpau libvdpau-va-gl virtualbox virtualbox-host-modules-arch $pacman_options
	fi
	systemctl enable NetworkManager
	systemctl enable lightdm
	systemctl enable ntpd

	echo "Disable systemd-networkd.service. We have NetworkManager."
	[[ -e /etc/systemd/system/multi-user.target.wants/systemd-networkd.service ]] && rm /etc/systemd/system/multi-user.target.wants/systemd-networkd.service
	[[ -e /etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service ]] && rm /etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service
	[[ -e /etc/systemd/system/sockets.target.wants/systemd-networkd.socket ]] && rm /etc/systemd/system/sockets.target.wants/systemd-networkd.socket
	echo
}

# Install grub
function install_grub() {
	echo "${red}***********************************"
	echo "Grub Installation"
	echo "***********************************${reset}"
	echo
	grub-install --target=i386-pc --no-floppy --recheck /dev/sda
	grub-mkconfig -o /boot/grub/grub.cfg
	echo
}

function clean_up() {
	# Remove install scripts from root
	# (Exits chroot.sh - back into install.sh - and reboots from that script)
	echo "${green}Clean up${reset}"
	chown -R $user_name:$user_name /home/$user_name
	su $user_name -c "yes | yay -Scc"
	# rm -r /myconfig
	rm /desktop_pkg.txt
	rm /chroot.sh
}

real_or_vm
set_root_pw
create_user
set_hostname
set_timezone
install_packages
install_grub
clean_up
