# Personal Archlinux Install Script  for my live iso Packarch

**Installation:**  

Boot Packarch, create the required GPT partitions:
- sda1 8Mb unformated with bios-boot flag
- sda2 for root
- sda3 for home

```bash
pacman -Sy git  
git clone https://github.com/Antidote1911/archinstall
cd archinstall && ./archinstall.sh
```
