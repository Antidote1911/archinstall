#!/bin/bash
#

disk_list=""
disk_install=""
swap_size=0
swap_part=""
root_part=""

# Get confirmation
function get_confirmation() {
	ret=-1
	echo $1
	echo -n "Enter y/n to confirm: "
	while [ $ret -lt 0 ]; do
		read response
		if [ "$response" == "y" ] || [ "$response" == "yes" ]; then
			ret=0
		elif [ "$response" == "n" ] || [ "$response" == "no" ]; then
			ret=1
		else
			echo -n "Got stones in your ears? It's y/n only: "
		fi
	done
	return $ret
}

# Display title and info about installer
function title() {
	echo "-----------------------------"
	echo "| Arch Linux Quick Installer |"
	echo "----------------------------"
	echo "This process will completely obliterate anything on the drive you select to install on!"
	echo "This only does MBR/BIOS since I don't have a need to set up an EFI boot partition."
	echo "GPT is bloat."
	echo
	echo
}

function increasecowspace() {
	echo "-----------------------------"
	echo "| Increase cowspace to 2 GB  |"
	echo "----------------------------"
	# or this in grub boot options: cow_spacesize=2G
	mount -o remount,size=2G /run/archiso/cowspace
	loadkeys fr-pc
	timedatectl set-ntp true
	echo
	echo
}

function preparedisk() {
	echo -e "------------------"
	echo -e "| 4. Base Install |"
	echo -e "------------------"
	echo
	echo "A choice? You get ext4 for root partition."
	echo "Oh, you wanted butterfs, xfs or something? Freedom?"
	echo ">>> https://wiki.archlinux.org/index.php/Installation_Guide"
	echo

	get_confirmation "You are about to format and lose everything on disk."
	if [ $? -eq 1 ]; then
		echo
		echo "Quitting. Nothing written to disk yet."
		echo
		exit 1
	fi

  # for my pc...
	mkfs.ext4 /dev/sda2 -L root
	mkfs.ext4 /dev/sdb1 -L home
	mount /dev/sda2 /mnt
	mkdir /mnt/home && mount /dev/sdb1 /mnt/home
	echo
	echo

  # for vbox tests...
	# mkfs.ext4 /dev/sda1 -L root
	# mkfs.ext4 /dev/sda2 -L home
	# mount /dev/sda1 /mnt
	# mkdir /mnt/home && mount /dev/sda2 /mnt/home
	# echo
	# echo
}

function install_base() {
	echo -e "--------------------------"
	echo -e "| 5. Install Base System | "
	echo -e "--------------------------"
	echo
	pacstrap /mnt base base-devel linux linux-firmware amd-ucode nano
}

function pre_chroot() {
	echo "CREATING FSTAB FOR NEW SYSTEM"
	genfstab -U /mnt >> /mnt/etc/fstab
	cp post-install-notes desktop_pkg.txt chroot.sh /mnt
	echo
	echo
}

function prompt_reboot() {
	echo -e "------------"
	echo -e "| COMPLETE |"
	echo -e "------------"
	echo
	echo "Installation complete!"
	echo "Remove usb and reboot your system homey."
}

title
increasecowspace
preparedisk
install_base
pre_chroot
arch-chroot /mnt ./chroot.sh
prompt_reboot
