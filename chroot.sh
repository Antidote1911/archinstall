#!/bin/bash
#
(
set -e

# Globals
user_name=""
user_pw=""
root_pw=""
host_name=""
vm_setting=""
pacman_options="--noconfirm --needed"
yay_options="--quiet --noconfirm --mflags --skipinteg"
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
	echo
	echo -n "Enter desired hostname: "
	read host_name
	echo $host_name > /etc/hostname
	echo "127.0.1.1 $host_name.localdomain $host_name" >> /etc/hosts
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

	# Patch makepkg so we can run as it as root.
	sed -i 's/EUID == 0/EUID == -1/' /usr/bin/makepkg

	# Install yay
	echo "Install Yay"
	su $user_name -c 'cd; git clone https://aur.archlinux.org/yay-bin.git'
	su $user_name -c 'cd; cd yay-bin; makepkg'
	pushd /home/$user_name/yay-bin/
	pacman -U *.pkg.tar.zst $pacman_options
	popd
	rm -rf /home/$user_name/yay-bin

	# do a yay system update
  su $user_name -c "yay -Syyu $yay_options"

	# Packages from the AUR can now be installed like this:
  # su $user_name -c 'yay -S --needed --noprogressbar --needed --noconfirm PACKAGE'
	# or not from AUR, use it like pacman yay -Sy PACKAGE

	# Install some AUR packages
	su $user_name -c "yay -S $yay_options pamac-aur font-manager kvantum-theme-arc numix-icon-theme-git numix-circle-icon-theme-git numix-gtk-theme "

	# Unpatch makepkg if you want
	#sed -i 's/EUID == -1/EUID == 0/' /usr/bin/makepkg

	# video drivers
	if [[ $vm_setting == 0 ]]; then
  	echo "${green}Installation des paquets pour la machine virtuelle${reset}"
  	pacman -S virtualbox-guest-utils $pacman_options
  	systemctl enable vboxservice

	elif [[ $vm_setting == 1 ]]; then
  	echo "${green}Installation des paquets pour la machine réelle${reset}"
  	pacman -S nvidia  nvidia-settings virtualbox virtualbox-host-modules-arch $pacman_options
	fi

	# Install scripts, dotfiles, themes from github
	systemctl enable NetworkManager
	systemctl enable lightdm.service
	systemctl enable ntpd.service
	echo
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


function customization() {
	echo "${red}***********************************"
	echo "Customization"
	echo "***********************************${reset}"
	echo
	echo
	git clone https://github.com/Antidote1911/xfce_config.git
	cp -r /xfce_config/backgrounds/packarch /usr/share/backgrounds/
	cp -r /xfce_config/packarch-icon.png /usr/share/pixmaps/packarch-icon.png
	cp -r /xfce_config/00-keyboard.conf /etc/X11/xorg.conf.d/00-keyboard.conf
	cp -r /xfce_config/environment /etc/environment
	cp -r /xfce_config/.config /home/$user_name/
	cp -r /xfce_config/.local /home/$user_name/
	######    Lightdm config    #########
	cp -r /xfce_config/lightdm-gtk-greeter.conf /etc/lightdm/lightdm-gtk-greeter.conf
	cp -r /xfce_config/lightdm.conf /etc/lightdm/lightdm.conf

	if [[ $vm_setting == 1 ]]; then
  	cp -r /xfce_config/20-nvidia.conf /etc/X11/xorg.conf.d/20-nvidia.conf
	fi

}

function clean_up() {
	# Remove install scripts from root
	# (Exits chroot.sh - back into install.sh - and reboots from that script)
	echo "${green}Clean up${reset}"
	su $user_name -c "yes | yay -Scc"
	rm -r /xfce_config
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
customization
clean_up

) 2>&1 | tee chroot.log
