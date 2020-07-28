#!/bin/bash
#


# Globals
user_name=""
user_pw=""
root_pw=""
host_name=""
pacman_options="--quiet --noconfirm --needed"
yay_options="--quiet --noconfirm --mflags --skipinteg"

function set_root_pw() {
	echo "-----------------"
	echo "| Root Password |"
	echo "-----------------"
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


function set_timezone() {
	echo "-----------------------"
	echo "| Locale and Timezone |"
	echo "-----------------------"
	echo

	# Set locale, symlink to local time
	echo 'fr_FR.UTF-8 UTF-8' >>/etc/locale.gen
	locale-gen
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

	# Check video drivers
	echo "Checking graphics card..."
	ati=$(lspci | grep VGA | grep ATI)
	nvidia=$(lspci | grep VGA | grep NVIDIA)
	intel=$(lspci | grep VGA | grep Intel)
	amd=$(lspci | grep VGA | grep AMD)

	if [ ! -z "$ati" ]; then
	    echo 'Ati graphics detected'
	    yay -Sy $yay_options xf86-video-ati
	fi
	if [ ! -z "$nvidia" ]; then
	    echo 'Nvidia graphics detected'
	    yay -Sy $yay_options xf86-video-nouveau
	fi
	if [ ! -z  "$intel" ]; then
	    echo 'Intel graphics detected'
	    yay -Sy $yay_options xf86-video-intel
	fi
	if [ ! -z  "$amd" ]; then
	    echo 'AMD graphics detected'
	    yay -Sy $yay_options xf86-video-amdgpu
	fi

	# Install scripts, dotfiles, themes from github
	systemctl enable lightdm.service
	systemctl enable ntpd.service
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
	rm /base_pkg.txt
	rm /desktop_pkg.txt
	rm /chroot.sh
}

set_root_pw
set_timezone
create_user
install_packages
install_grub
clean_up
