#!/bin/bash
#


# Globals
user_name=""
user_pw=""
root_pw=""
host_name=""

function set_root_pw() {
	clear
	echo "-----------------"
	echo "| Root Password |"
	echo "-----------------"
	echo
	pass_ok=0
	while [ $pass_ok -eq 0 ]; do
		echo
		echo -n 'Set password for root: '
		read root_pw
		echo -n 'Confirm password for root: '
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


function set_timezone() {
	echo "-----------------------"
	echo "| Locale and Timezone |"
	echo "-----------------------"
	echo

	# Set locale, symlink to local time
	echo 'fr_FR.UTF-8 UTF-8' >>/etc/locale.gen
	locale-gen
	clear
	ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
	hwclock --systohc --utc
	echo
	echo
}

# Create user, password, change hostname
function create_user() {
	echo "-----------------"
	echo "| User Creation |"
	echo "-----------------"
	echo
	echo -n "Enter desired username: "
	read user_name
	echo
	useradd -m -G wheel -s /bin/bash $user_name
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
	echo

	echo
	echo -n "Enter desired hostname: "
	read host_name
	echo $host_name > /etc/hostname
	echo
	echo

	# Add user to wheel
	echo "" >> /etc/sudoers
	echo "## Allow members of group wheel to execute any command" >> /etc/sudoers
	echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
	echo "## Enable password feedback" >> /etc/sudoers
	echo "Defaults env_reset,pwfeedback" >> /etc/sudoers

}


function install_packages() {
	echo "------------------------"
	echo "| Package Installation |"
	echo "------------------------"
	echo

	# Install yay
	# Patch makepkg so we can run as it as root.
	sed -i 's/EUID == 0/EUID == -1/' /usr/bin/makepkg
	git clone https://aur.archlinux.org/yay.git
	cd yay
	yes | makepkg -si --needed --noconfirm --skippgpcheck
	wait
	cd
	rm -rf yay

	# Install packages
	yay -S -y --quiet --noconfirm --mflags --skipinteg pamac-aur bspwm sxhkd polybar-git grub pulseaudio pulseaudio-alsa pavucontrol networkmanager network-manager-applet xf86-input-libinput mesa xorg xorg-xinit xorg-xbacklight redshift feh htop vim firefox base-devel bash-completion git acpi zathura zathura-djvu zathura-pdf-mupdf wget dmenu netctl dialog dhcpcd
	# Unpatch makepkg
	#sed -i 's/EUID == -1/EUID == 0/' /usr/bin/makepkg
	# Check video drivers
	echo "Checking graphics card..."
	ati=$(lspci | grep VGA | grep ATI)
	nvidia=$(lspci | grep VGA | grep NVIDIA)
	intel=$(lspci | grep VGA | grep Intel)
	amd=$(lspci | grep VGA | grep AMD)

	if [ ! -z "$ati" ]; then
	    echo 'Ati graphics detected'
	    yay -S -y --quiet --noconfirm xf86-video-ati
	fi
	if [ ! -z "$nvidia" ]; then
	    echo 'Nvidia graphics detected'
	    yay -S -y --quiet --noconfirm xf86-video-nouveau
	fi
	if [ ! -z  "$intel" ]; then
	    echo 'Intel graphics detected'
	    yay -S -y --quiet --noconfirm xf86-video-intel
	fi
	if [ ! -z  "$amd" ]; then
	    echo 'AMD graphics detected'
	    yay -S -y --quiet --noconfirm xf86-video-amdgpu
	fi

	# Install scripts, dotfiles, themes from github
	git clone https://github.com/cadwalladr/scripts "/home/${user_name}/.scripts"
	chown -R "/home/${user_name}/.scripts"
	chgrp -R "/home/${user_name}/.scripts"

	git clone https://github.com/cadwalladr/bspwm-themes "/home/${user_name}/bspwm-themes"
	chown -R "/home/${user_name}/bspwm-themes"
	chgrp -R "/home/${user_name}/bspwm-themes"
	echo "exec bspwm -c ~/.config/bspwm/soren" > "/home/${user_name}/.xinitrc"
	chmod +x "/home/${user_name}/.xinitrc"
	chown -R "/home/${user_name}/.xinitrc"
	chgrp -R "/home/${user_name}/.xinitrc"

	git clone https://github.com/cadwalladr/doot "/home/${user_name}/doot"
	chown -R "/home/${user_name}/doot"
	chgrp -R "/home/${user_name}/doot"
	echo
	echo
}


# Install grub
function install_grub() {
	echo "---------------------"
	echo "| Grub Installation |"
	echo "---------------------"
	echo
	grub-install --target=i386-pc --no-floppy --recheck /dev/sda
	grub-mkconfig -o /boot/grub/grub.cfg
	echo
}

function clean_up() {
	# Remove install scripts from root
	# (Exits chroot.sh - back into install.sh - and reboots from that script)
	rm /chroot.sh
}

set_root_pw
set_timezone
create_user
install_packages
install_grub
clean_up
