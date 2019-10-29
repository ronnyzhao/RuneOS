RuneOS
---
- For all Raspberry Pi: 0, 1, 2, 3 and 4 (3A+ and 3B+: not yet tested but should work)
- Build RuneAudio+R from [**Arch Linux Arm**](https://archlinuxarm.org/about/downloads) releases.
- With options to exclude features, it can be as light as possible in terms of build time and disk space.

**Procedure**
- Download and write to `ROOT` and `BOOT` partitions
- Start Arch Linux Arm
- Upgrade to latest kernel and packages
- Install packages
- Download web interface, custom packages and config files
- Install custom packages
- Configure settings

**Need**
- Linux PC (or Linux in VirtualBox on Windows with network set as `Bridge Adapter`)
- Raspberry Pi
- Wired LAN connection (if not available, monitor + keyboard)
- Normal SD mode
	- Micro SD card - 4GB+ - `BOOT` + `ROOT` partitions
- USB mode (for hard drive or fast thumb drive)
	- Micro SD card - 100MB+ - `BOOT` partition only
	- USB drive - 4GB+ - `ROOT` partition (or existing USB hard drive with data)
---

### Build

**Download Arch Linux Arm**

| Model        | SoC       | File                             |
|--------------|-----------|----------------------------------|
| RPi Z, A, B  | BCM2835   | ArchLinuxARM-rpi-latest.tar.gz   |
| RPi 2B, 3B   | BCM2837   | ArchLinuxARM-rpi-2-latest.tar.gz |
| RPi 3A+, 3B+ | BCM2837B0 | ArchLinuxARM-rpi-3-latest.tar.gz |
| RPi 4B       | BCM2711   | ArchLinuxARM-rpi-4-latest.tar.gz |

- On Linux PC
	- Command lines - gray code blocks
	- Copy > paste unless corrections needed
	- Comments - Lines with leading `#` can be skipped.
```sh
# switch user to root
su

# download - replace with matched model
file=ArchLinuxARM-rpi-2-latest.tar.gz

wget -qN --show-progress http://os.archlinuxarm.org/os/$file
# if downlod is too slow, Ctrl+C > rm $file and try again
```
- While waiting for download to finish, go to next step.

**Prepare partitions**
- SD card mode (normal)
	- Insert micro SD card
	- Delete all partitions (make sure it's the micro SD card)
	- Create partitions with **GParted** app

| No. | Size        | Type    | Format | Label |
|-----|-------------|---------|--------|-------|
| #1  | 100MiB      | primary | fat32  | BOOT  |
| #2  | (the rest)  | primary | ext4   | ROOT  |
	
- USB drive mode (run RuneAudio+R from USB drive)
	- Insert Micro SD card
		- Delete all partitions (make sure it's the micro SD card)
		- Format: `fat32`
		- Label: `BOOT`
	- Plug in USB drive
		- Blank:
			- Delete all partitions (make sure it's the USB drive)
			- Format: `ext4`
			- Label: `ROOT`
		- With existing data:
			- No need to change format of existing partition
			- Resize the existing to get 4GB unallocated space (anywhere - at the end, middle or start of the disk)
			- Create a new partition in the unallocated space
				- Format: `ext4`
				- Label: `ROOT`

**Write `ROOT` partition**
- Open **Files** app
- Click `BOOT` and `ROOT` to mount
```sh
# install packages (skip if already installed)
apt install bsdtar nmap  # arch linux: pacman -S bsdtar nmap

# function for verify names
cols=$( tput cols )
showData() {
    printf %"$cols"s | tr ' ' -
    echo $1
    echo $2
    printf %"$cols"s | tr ' ' -
}

# get ROOT partition and verify
ROOT=$( df | grep ROOT | awk '{print $NF}' )
showData "$( df -h | grep ROOT )" "ROOT = $ROOT"

# expand to ROOT
bsdtar xpvf $file -C $ROOT  # if errors - install missing packages

# wait until writing finished, delete downloaded file
rm $file
```

**Write `BOOT` partition**
```sh
# get BOOT partition and verify
BOOT=$( df | grep BOOT | awk '{print $NF}' )
showData "$( df -h | grep BOOT )" "BOOT = $BOOT"

# move to BOOT
mv -v $ROOT/boot/* $BOOT 2> /dev/null

# (skip - RPi 0, 1) boot splash
cmdline='root=/dev/mmcblk0p2 rw rootwait console=ttyAMA0,115200 selinux=0 fsck.repair=yes smsc95xx.turbo_mode=N dwc_otg.lpm_enable=0 '
cmdline+='kgdboc=ttyAMA0,115200 elevator=noop console=tty3 plymouth.enable=0 quiet loglevel=0 logo.nologo vt.global_cursor_default=0'
echo $cmdline > $BOOT/boot/cmdline.txt

# (skip - NOT RPi 0) fix: kernel panic
[[ $model == 09 || $model == 0c ]] && sed -i -e '/force_turbo=1/ i\over_voltage=2' -e '/dtparam=audio=on/ a\hdmi_drive=2' /boot/config.txt
```

(skip - SD card mode) **Setup USB as root partition**
```sh
# get UUID and verify
dev=$( df | grep ROOT | awk '{print $1}' )
uuid=$( /sbin/blkid | grep $dev | cut -d' ' -f3 | tr -d '"' )
showData "$( df -h | grep ROOT )" $uuid

# set root device
sed -i "s|/dev/mmcblk0p2|$uuid|" $BOOT/cmdline.txt
echo "$uuid  /  ext4  defaults  0  0" >> $ROOT/etc/fstab
```

**Unmount and remove**
- Click `Unmount` in **Files** or:
```sh
umount -l $BOOT
umount -l $ROOT
```

**Start Arch Linux Arm**
- Move micro SD card (and USB drive if in USB drive mode) to RPi
- Remove all other USB devices, Wi-Fi, bluetooth, mouse
- Connect wired LAN (If not available or RPi 0 W, connect monitor + keyboard)
- Power on
- Wait 30 seconds (On connected monitor at login prompt)

(skip - wired LAN) **Connect Wi-Fi** :
```sh
# login
alarm  # password: alarm

# switch user to root
su # password: root

# connect wi-fi
wifi-menu

# (skip - NOT RPi 0, 1) fix dns errors
date -s YYYYMMDD  # replace YYYYMMDD
systemctl stop systemd-resolved
```
- Then continue at Packages

(skip - no network connection) **Connect PC to RPi**
```sh
# get RPi IP address and verify - skip to ### connect ### for known IP
routerip=$( ip route get 1 | cut -d' ' -f3 )
nmap=$( nmap -sP ${routerip%.*}.* | grep -B2 Raspberry )

rpiip=$( echo "$nmap" | head -1 | awk '{print $NF}' | tr -d '()' )
showData "$nmap" "RPi IP = $rpiip"

# if already known IP or there's more than 1 RPi, set rpiip manually
# rpiip=IP_ADDRESS

ssh-keygen -R $rpiip 2> /dev/null  # remove existing key if any

ssh alarm@$rpiip  # password: alarm
```
- If `ssh` failed, start all over again. (A lot of `[FAILED]` on connected monitor)

(skip - connected Wi-Fi) **Initialize and upgrade**
```sh
# switch user to root
su # password: root

# change directory to root
cd

# initialize pgp key
pacman-key --init
pacman-key --populate archlinuxarm

# fill entropy pool (fix - Kernel entropy pool is not initialized)
systemctl start systemd-random-seed

# system-wide kernel and packages upgrade
pacman -Syu
# if download is too slow or stuck, Ctrl+C then pacman -Syu again
```

**(Optional) Create image of Arch Linux Arm**
- To save time for all previous steps

**Packages**
```sh
# package list
packages='alsa-utils avahi bluez bluez-utils chromium cronie dnsmasq dosfstools ffmpeg gcc hostapd '
packages+='ifplugd imagemagick mpd mpc nfs-utils nss-mdns ntfs-3g parted php-fpm python python-pip '
packages+='samba shairport-sync sudo udevil wget xorg-server xf86-video-fbdev xf86-video-vesa xorg-xinit'

# get RPi model
model=$( cat /proc/cpuinfo | grep Revision | tail -c 4 | cut -c 1-2 )
echo 00 01 02 03 04 09 | grep -q $model && nobt=1 || nobt=
```

(skip - RPi 3, 4) **Exclude for hardware support**
```sh
# RPi 0, 1 - no browser on rpi (too much for CPU)
packages=${packages/ chromium}
packages=${packages/ xorg-server xf86-video-fbdev xf86-video-vesa xorg-xinit}

# remove bluetooth if not RPi 0 W, 3, 4
[[ $nobt ]] && packages=${packages/ bluez bluez-utils}
```

(skip - install all) **Exclude optional packages**
```sh
# remove connect by name: runeaudio.local
packages=${packages/ avahi}

# remove bluetooth support
packages=${packages/ bluez bluez-utils}

# remove access point
packages=${packages/ dnsmasq}
packages=${packages/ hostapd}

# remove airplay
packages=${packages/ shairport-sync}

# remove browser on rpi
packages=${packages/ chromium}
packages=${packages/ xorg-server xf86-video-fbdev xf86-video-vesa xorg-xinit}

# remove extended audio format:
#   16sv 3g2 3gp 4xm 8svx aa3 aac ac3 adx afc aif aifc aiff al alaw amr anim apc ape asf atrac au aud avi avm2 avs 
#   bap bfi c93 cak cin cmv cpk daud dct divx dts dv dvd dxa eac3 film flac flc fli fll flx flv g726 gsm gxf iss 
#   m1v m2v m2t m2ts m4a m4b m4v mad mj2 mjpeg mjpg mka mkv mlp mm mmf mov mp+ mp1 mp2 mp3 mp4 mpc mpeg mpg mpga mpp mpu mve mvi mxf 
#   nc nsv nut nuv oga ogm ogv ogx oma ogg omg opus psp pva qcp qt r3d ra ram rl2 rm rmvb roq rpl rvc shn smk snd sol son spx str swf 
#   tak tgi tgq tgv thp ts tsp tta xa xvid uv uv2 vb vid vob voc vp6 vmd wav webm wma wmv wsaud wsvga wv wve
packages=${packages/ ffmpeg}

# remove file sharing
packages=${packages/ samba}

# remove python (to install UPnP, do not remove)
packages=${packages/ python python-pip}
```

**Install packages**
```sh
# install packages
pacman -S $packages

# optional - install RPi.GPIO
pip --no-cache-dir install RPi.GPIO
```

**RuneUI, custom packages and config files**
- RuneAudio Enhancement interface
- Custom packages (not available as standard package)
	- `nginx-mainline-pushstream`
	- `kid3-cli`
	- `matchbox-window-manager`
	- `bluealsa`
	- `upmpdcli`
- Configuration files set to default
- Initialize / restore database and settings
```sh
# get custom packages and setup files
wget -q --show-progress https://github.com/rern/RuneOS/archive/master.zip

# expand to target directories
bsdtar xvf *.zip --strip 1 --exclude=.* --exclude=*.md -C /
[[ $nobt ]] && rm bluealsa* /boot/overlays/bcmbt.dtbo

# set permissions and ownership
chmod 755 /srv/http/* /srv/http/settings/* /usr/local/bin/*
chown -R http:http /srv/http

# (skip - NOT RPi 0, 1) no splash, hdmi sound, armv6h packages
if echo 00 01 02 03 04 09 0c | grep -q $model; then
    # RPi 0 - fix: kernel panic
    [[ $model == 09 || $model == 0c ]] && sed -i -e '/force_turbo=1/ i\over_voltage=2' -e '/dtparam=audio=on/ a\hdmi_drive=2' /boot/config.txt
    # RPi 0 - only W has wifi and bluetooth
    [[ $model != 0c ]] && sed -i '/disable-wifi\|disable-bt/ d' /boot/config.txt
    rm *.pkg.tar.xz
    mv armv6h/* .
fi
```

(skip - install all) **Exclude optional packages**
```sh
# remove bluetooth
rm -f bluealsa*

# remove metadata tag editor
rm -f kid3-cli*

# remove UPnP
rm -f libupnpp* upmpdcli*
```

(skip - install all) **Exclude removed packages configurations**
```sh
[[ ! -e /usr/bin/avahi-daemon ]] && rm -r /etc/avahi/services
if [[ ! -e /usr/bin/chromium ]]; then
    rm -f libmatchbox* matchbox*
    rm /etc/systemd/system/localbrowser*
    rm /etc/X11/xinit/xinitrc
fi
[[ ! -e /usr/bin/bluetoothctl ]] && rm -r /etc/systemd/system/bluetooth.service.d
[[ ! -e /usr/bin/hostapd ]] && rm -r /etc/{hostapd,dnsmasq.conf}
[[ ! -e /usr/bin/smbd ]] && rm -r /etc/samba
[[ ! -e /usr/bin/shairport-sync ]] && rm /etc/systemd/system/shairport*
```

**Install custom packages**
```sh
# install
pacman -U *.pkg.tar.xz

# remove cache and custom package files
rm -rf /var/cache/pacman/pkg/* *.pkg.tar.xz *.zip /root/armv6h

# (skip - removed UPnP) upmpdcli - fix missing symlink and generate RSA private key
if [[ -e /usr/bin/upmpdcli ]]; then
    ln -s /lib/libjsoncpp.so.{21,20}
    mpd --no-config 2> /dev/null
    upmpdcli -c /etc/upmpdcli.conf
fi
# Ctrl+C when done
killall mpd
```

**Configurations**
```sh
# configure settings
runeconfigure.sh
```

**Finish**
```sh
# reboot
shutdown -r now
```
---

**Optional - Create image file**
- Once start RuneAudio+R successfully
- Power off
- Move micro SD card (and the USB drive, if `ROOT` partition is in USB drive) to PC
- Resize `ROOT` partition to smallest size possible with **GParted** app
	- menu: GParted > Devices > /dev/sd?
	- right-click `ROOT` partiton > Unmount
	- right-click `ROOT` partiton > Resize/Move
	- drag rigth triangle to fit minimum size
	- menu: Edit > Apply all operations
- Create image - **SD card mode**
	- on Windows (much faster): [Win32 Disk Imager](https://sourceforge.net/projects/win32diskimager/) > Read only allocated partitions
	- OR
```sh
# get device and verify
part=$( df | grep BOOT | awk '{print $1}' )
dev=${part:0:-1}
df | grep BOOT
echo device = $dev

# get partition end and verify
fdisk -u -l $dev
end=$( fdisk -u -l $dev | tail -1 | awk '{print $3}' )
echo end = $end

# create image
dd if=$dev of=RuneAudio+Re2.img count=$(( end + 1 )) status=progress  # remove status=progress if errors
```
- Create image - **USB drive mode**
	- Open **Disks** app - select drive > select partition > cogs button > Create Partition Image
		- Micro SD card
		- USB drive
