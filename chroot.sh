#!/bin/bash
#

set -e

# Globals
user_name=""
user_pw=""
root_pw=""
host_name=""
vm_setting=""
oh_my_zsh=""
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
	echo
	echo -n "Enter desired hostname: "
	read host_name
	echo $host_name > /etc/hostname
	echo "127.0.0.1 $host_name.localdomain $host_name" >> /etc/hosts
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

function oh_my_zsh() {
	echo "${red}***********************************"
	echo "Install Oh-my-zsh ?"
	echo "***********************************${reset}"
	echo
	read -p "0 - oui, 1 - non: " oh_my_zsh
}


function install_packages() {
	echo "${red}***********************************"
	echo "Package Installation"
	echo "***********************************${reset}"
	echo
        # Install packages
	pacman -Syu - < desktop_pkg.txt $pacman_options

	# Patch makepkg so we can run as it as root.
	# sed -i 's/EUID == 0/EUID == -1/' /usr/bin/makepkg

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
	su $user_name -c "yay -S $yay_options spotify polybar-spotify-module cava pamac-aur font-manager kvantum-theme-arc colorpicker betterlockscreen networkmanager-dmenu-git perl-linux-desktopfiles polybar rofi-git"
    # su $user_name -c "yay -S $yay_options spotify polybar-spotify-module cava"
    
	# Unpatch makepkg if you want
	# sed -i 's/EUID == -1/EUID == 0/' /usr/bin/makepkg

	# video drivers
	if [[ $vm_setting == 0 ]]; then
  	echo "${green}Installation des paquets pour la machine virtuelle${reset}"
  	pacman -S virtualbox-guest-utils $pacman_options
  	systemctl enable vboxservice

	elif [[ $vm_setting == 1 ]]; then
  	echo "${green}Installation des paquets pour la machine réelle${reset}"
  	pacman -S nvidia  virtualbox virtualbox-host-modules-arch $pacman_options
	fi

	chsh --shell /bin/zsh $user_name
    chsh --shell /bin/zsh root	

	systemctl enable NetworkManager
	systemctl enable lightdm
	systemctl enable ntpd
    # systemctl --user enable spotify-listener

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

function customization() {
	echo "${red}***********************************"
	echo "Customization"
	echo "***********************************${reset}"
	echo
	echo
	git clone https://github.com/Antidote1911/myconfig.git

	rsync -av myconfig/homeuser/ /home/$user_name/ --inplace
	rsync -av myconfig/root/ /root --inplace
	rsync -av myconfig/usr/ /usr --inplace
	rsync -av myconfig/etc/ /etc --inplace

	if [[ $vm_setting == 1 ]]; then
  	cp -r /myconfig/20-nvidia.conf /etc/X11/xorg.conf.d/20-nvidia.conf
	fi
	
	if [[ $oh_my_zsh == 0 ]]; then
		echo "Setting Up Oh-My-Zsh"
		git clone https://github.com/robbyrussell/oh-my-zsh.git --depth 1 /home/$user_name/.oh-my-zsh
		cp /myconfig/archcraft.zsh-theme /home/$user_name/.oh-my-zsh/custom/themes/archcraft.zsh-theme
		# https://stackoverflow.com/questions/43402753/oh-my-zsh-not-applying-themes
		# su $user_name -c 'yay -Rncs --noconfirm grml-zsh-config'
		cp /home/$user_name/.oh-my-zsh/templates/zshrc.zsh-template /home/$user_name/.zshrc
		sed -i -e 's/ZSH_THEME=.*/ZSH_THEME="archcraft"/g' /home/$user_name/.zshrc
		# for root
		cp -r /home/$user_name/.oh-my-zsh /root/.oh-my-zsh
		cp /home/$user_name/.oh-my-zsh/templates/zshrc.zsh-template /root/.zshrc		
	fi
}

function clean_up() {
	# Remove install scripts from root
	# (Exits chroot.sh - back into install.sh - and reboots from that script)
	echo "${green}Clean up${reset}"
	chown -R $user_name:$user_name /home/$user_name
	su $user_name -c "yes | yay -Scc"
	rm -r /myconfig
	rm /desktop_pkg.txt
	rm /chroot.sh
}

real_or_vm
set_root_pw
create_user
set_hostname
set_timezone
oh_my_zsh
install_packages
install_grub
customization
clean_up
