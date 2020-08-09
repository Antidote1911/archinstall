# Personal Archlinux Install Script  

**Installation:**  

Boot Arch Install media, connect to the internet, and create the required GPT partitions:
- sda1 8Mb unformated with bios-boot flag
- sda2 for root
- sdb3 for home

```bash
pacman -Sy git  
git clone https://github.com/Antidote1911/archinstall
cd archinstall && ./archinstall.sh
```
