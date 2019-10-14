RuneOS
---
Build RuneAudio+R from [Arch Linux Arm](https://archlinuxarm.org/about/downloads) source
- Download Arch Linux Arm from source and write to SD card
- Start Arch Linux Arm
- Upgrade to latest kernel and packages
- Install packages
- Download web interface, custom packages and config files
- Install custom packages
- Fix and set configurations
- Create image file

**Need**
- Linux PC (or Linux in VirtualBox on Windows)
- Raspberry Pi
- Micro SD card - 4GB+ (with card reader)
- USB drive - 1GB+ (**`ext4`** format only) for running RuneAudio+R

**Download Arch Linux Arm**
- On Linux PC
```sh
sudo su

# download
#file=ArchLinuxARM-rpi-4-latest.tar.gz  # RPi4
#file=ArchLinuxARM-rpi-3-latest.tar.gz  # RPi3B+
#file=ArchLinuxARM-rpi-2-latest.tar.gz  # RPi2, RPi3
#file=ArchLinuxARM-rpi-latest.tar.gz    # RPi1, RPi Zero

# replace with required version
file=ArchLinuxARM-rpi-2-latest.tar.gz

### download ### -----------------------------------
wget http://os.archlinuxarm.org/os/$file
```

**Write to SD card**
- Insert Micro SD card
- Create partitions with **GParted** (or command line with: `fdisk` + `fatlabel` + `e2label`)

| Type    | No. | Label* | Format | Size       |
|---------|-----|--------|--------|------------|
| primary | #1  | BOOT   | fat32  | 100MB      |
| primary | #2  | ROOT   | ext4   | (the rest) |

\* **Label** - Important  
- Click them in Files/Nautilus to mount.

```sh
# install bsdtar and nmap
apt install bsdtar nmap

# get partitions and verify
ROOT=$( df | grep ROOT | awk '{print $NF}' )
BOOT=$( df | grep BOOT | awk '{print $NF}' )
df | grep 'ROOT\|BOOT'
echo ROOT = $ROOT
echo BOOT = $BOOT

### expand to sd card ### -----------------------------------
bsdtar xpvf $file -C $ROOT  # if errors - install missing package

# move boot directory
cp -rv --no-preserve=mode,ownership $ROOT/boot/* $BOOT
rm -r $ROOT/boot/*
```
- 

**Start Arch Linux Arm**
- Remove all USB drives
- Move micro SD card to RPi
- Connect wired LAN
- Power on / connect RPi power

**Connect PC to RPi**
- Wait for login prompt (If no connected display, wait 30 seconds)
```sh
# get RPi IP address and verify - skip to ### connect ### for known IP
routerip=$( ip route get 1 | cut -d' ' -f3 )
nmap=$( nmap -sP ${routerip%.*}.* | grep -B2 Raspberry )
rpiip=$( echo "$nmap" | head -1 | awk '{print $NF}' | tr -d '()' )
echo List:
echo "$nmap"
echo RPi IP = $rpiip

### connect ### -----------------------------------
# already known IP or if there's more than 1 RPi, set rpiip manually
# rpiip=<IP>

ssh alarm@$rpiip  # password: alarm

# if WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED! - remove existing key
ssh-keygen -R $rpiip
```

**Packages**
```sh
# switch user to root
su # password: root

# change directory to root
cd

# initialize pgp key
pacman-key --init
pacman-key --populate archlinuxarm

### full system-wide upgrade ### -----------------------------------
pacman -Syu

# package list
packages='alsa-utils avahi chromium cronie dnsmasq dosfstools ffmpeg gcc hostapd ifplugd mpd mpc nfs-utils parted php-fpm python python-pip samba shairport-sync sudo udevil wget xorg-server xf86-video-fbdev xf86-video-vesa xorg-xinit'
```

**Exclude optional packages** (Skip to install all)
```sh
# optional - remove access point
packages=${packages/ dnsmasq}
packages=${packages/ hostapd}

# optional - remove airplay
packages=${packages/ shairport-sync}

# optional - remove browser on rpi
packages=${packages/ chromium}
packages=${packages/ xorg-server xf86-video-fbdev xf86-video-vesa xorg-xinit}

# optional - remove extended audio format:
#   16sv 3g2 3gp 4xm 8svx aa3 aac ac3 adx afc aif aifc aiff al alaw amr anim apc ape asf atrac au aud avi avm2 avs 
#   bap bfi c93 cak cin cmv cpk daud dct divx dts dv dvd dxa eac3 film flac flc fli fll flx flv g726 gsm gxf iss 
#   m1v m2v m2t m2ts m4a m4b m4v mad mj2 mjpeg mjpg mka mkv mlp mm mmf mov mp+ mp1 mp2 mp3 mp4 mpc mpeg mpg mpga mpp mpu mve mvi mxf 
#   nc nsv nut nuv oga ogm ogv ogx oma ogg omg opus psp pva qcp qt r3d ra ram rl2 rm rmvb roq rpl rvc shn smk snd sol son spx str swf 
#   tak tgi tgq tgv thp ts tsp tta xa xvid uv uv2 vb vid vob voc vp6 vmd wav webm wma wmv wsaud wsvga wv wve
packages=${packages/ ffmpeg}

# optional - remove file sharing
packages=${packages/ samba}

# optional - remove python
packages=${packages/ python python-pip}
```

**Install packages**
```sh
### install packages ### -----------------------------------
pacman -S $packages

# if errors - temporarily bypass key verifications
# sed -i '/^SigLevel/ s/^/#/; a\SigLevel    = TrustAll' /etc/pacman.conf

# start systemd-random-seed (fix - Kernel entropy pool is not initialized)
systemctl start systemd-random-seed

# optional - install RPi.GPIO
pip install RPi.GPIO

# remove cache
rm /var/cache/pacman/pkg/*
```

**Web interface, custom packages and config files**
- RuneAudio Enhancement interface
- Custom packages
	- `nginx-mainline` - support pushstream
	- `kid3-cli` - not available as standard package
	- `matchbox-window-manager` - not available as standard package
	- `upmpdcli` - not available as standard package
	- `ply-image` (single binary file)
- Configuration files set to default
- `Runonce.sh` for initial boot setup
```sh
### download ### -----------------------------------
wget -q --show-progress https://github.com/rern/RuneOS/archive/master.zip
bsdtar xvf master.zip --strip 1 --exclude=.* --exclude=*.md -C /
chmod -R 755 /srv/http /usr/local/bin
chown -R http:http /srv/http
```

**Exclude optional packages** (Skip to install all)
```sh
# optional - remove metadata tag editor
rm kid3-cli*

# optional - remove UPnP
rm upmpdcli*
```

**Install custom packages**
```sh
### install custom packages ### -----------------------------------
pacman -U *.pkg.tar.xz
rm *.pkg.tar.xz
```

**Fixes**
```sh
# account expired
users=$( cut -d: -f1 /etc/passwd )
for user in $users; do
	chage -E -1 $user
done

# lvm - Invalid value
sed -i '/event_timeout/ s/^/#/' /usr/lib/udev/rules.d/11-dm-lvm.rules

# mpd - file not found
touch /var/log/mpd.log
chown mpd:audio /var/log/mpd.log

# upmpdcli - older symlink
ln -s /lib/libjsoncpp.so.{21,20}
```

**Configurations**
```sh
# bootsplash - set default image
ln -s /srv/http/assets/img/{NORMAL,start}.png

# cron - for addons updates
( crontab -l &> /dev/null; echo '00 01 * * * /srv/http/addonsupdate.sh &' ) | crontab -

# hostname - set default
name=RuneAudio
namecl=runeaudio
echo $namecl > /etc/hostname
sed -i "s/^\(ssid=\).*/\1$name/" /etc/hostapd/hostapd.conf &> /dev/null
sed -i 's/\(zeroconf_name           "\).*/\1$name"/' /etc/mpd.conf
sed -i "s/\(netbios name = \).*/\1$name/" /etc/samba/smb.conf &> /dev/null
sed -i "/name = .%H./ i\name = $name" /etc/shairport-sync.conf
sed -i "s/^\(friendlyname = \).*/\1$name/" /etc/upmpdcli.conf &> /dev/null
sed -i "s/\(.*\[\).*\(\] \[.*\)/\1$namelc\2/" /etc/avahi/services/runeaudio.service
sed -i "s/\(.*localdomain \).*/\1$namelc.local $namelc/" /etc/hosts

# login prompt - remove
systemctl disable getty@tty1

# mpd - music directories
mkdir -p /mnt/MPD/{USB,NAS}
chown -R mpd:audio /mnt/MPD

# motd - remove default
rm /etc/motd

# nginx - custom 50x.html
mv -f /etc/nginx/html/50x.html{.custom,}

# ntp - set default
sed -i 's/#NTP=.*/NTP=pool.ntp.org/' /etc/systemd/timesyncd.conf

# password - set default
echo root:rune | chpasswd

# ssh - permit root
sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# timezone - set default
timedatectl set-timezone UTC

# wireless-regdom
sed -i '/WIRELESS_REGDOM="00"/ s/^#//' /etc/conf.d/wireless-regdom

# startup services
systemctl daemon-reload
systemctl enable avahi-daemon bootsplash cronie devmon@mpd nginx php-fpm startup
```

**Finish**
```sh
# shutdown
shutdown -h now
```
- Wait until green LED stop flashing and off.
- Power off / disconnect RPi power

**Create image file**
- Move micro SD card to PC
- Resize `ROOT` partition to smallest size possible with **GParted**.
	- menu: GParted > Devices > /dev/sd?
	- right-click `ROOT` partiton > Unmount
	- right-click `ROOT` partiton > Resize/Move
	- drag rigth triangle to fit minimum size
	- menu: Edit > Apply all operations
- Create image file
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
dd if=$dev of=RuneAudio+Re2.img count=$(( end + 1 ))
```
OR on Windows (much faster):
- [Win32 Disk Imager](https://sourceforge.net/projects/win32diskimager/) > Read only allocated partitions

**Start RuneAudio+R**
- Move micro SD card to RPi
- Plug in USB drive
- Power on
