#!/bin/bash

# required packages
if [[ -e /usr/bin/pacman ]]; then
	[[ ! -e /usr/bin/bsdtar ]] && packages+='bsdtar '
	[[ ! -e /usr/bin/dialog ]] && packages+='dialog '
	[[ ! -e /usr/bin/nmap ]] && packages+='nmap '
	[[ ! -e /usr/bin/pv ]] && packages+='pv '
	[[ -n $packages ]] && pacman -S --noconfirm --needed $packages
else
	[[ ! -e /usr/bin/bsdtar ]] && packages+='bsdtar '
	[[ ! -e /usr/bin/dialog ]] && packages+='dialog '
	[[ ! -e /usr/bin/nmap ]] && packages+='nmap '
	[[ ! -e /usr/bin/pv ]] && packages+='pv '
	[[ -n $packages ]] && apt install -y $packages
fi

# remove on exit
trap 'rm -f ArchLinuxARM*; clear' EXIT

#----------------------------------------------------------------------------
infobox() {
	[[ -z $2 ]] && w=0 || w=$2
	[[ -z $3 ]] && h=0 || h=$3
	dialog --backtitle "$title" --colors --infobox "\n$1\n" $w $h
}
inputbox() {
	dialog --backtitle "$title" --colors --output-fd 1 --inputbox "\n$1" 0 0
}
msgbox() {
	[[ -z $2 ]] && w=0 || w=$2
	[[ -z $3 ]] && h=0 || h=$3
	dialog --backtitle "$title" --colors --msgbox "\n$1\n\n" $w $h
}
yesno() {
	dialog --backtitle "$title" --colors --yesno "\n$1\n\n" 0 0
}

title='Create Arch Linux Arm'
infobox "
                \Z1Arch Linux Arm\Z0\n
                      for\n
                 Raspberry Pi
" 7 50
sleep 3

BOOT=$( df | grep BOOT | awk '{print $NF}' )
ROOT=$( df | grep ROOT | awk '{print $NF}' )

# check mounts
[[ -z $BOOT ]] && warnings+='BOOT not mounted\n'
[[ -z $ROOT ]] && warnings+='ROOT not mounted\n'
# check duplicate names
[[ -n $BOOT && ${#[BOOT[@]} -gt 1 ]] && warnings+='BOOT has more than 1\n'
[[ -n $ROOT && ${#[ROOT[@]} -gt 1 ]] && warnings+='ROOT has more than 1\n'
# check empty to prevent wrong partitions
[[ -n $BOOT && -n $( ls $BOOT | grep -v 'System Volume Information' ) ]] && warnings+='BOOT not empty\n'
[[ -n $ROOT && -n $( ls $ROOT | grep -v 'lost+found' ) ]] && warnings+='ROOT not empty\n'
# partition warnings
if [[ -n $warnings ]]; then
	msgbox "\Z1Warnings:\n\n$warnings\Z0"
	clear && exit
fi

# get build data
getData() {
	yesno "\Z1Confirm path:\Z0\n\n\
BOOT: \Z1$BOOT\Z0\n\
ROOT: \Z1$ROOT\Z0"
	[[ $? == 1 || $? == 255 ]] && clear && exit

	rpi=$( dialog --backtitle "$title" --colors --output-fd 1 \
		--menu '\n\Z1Target:\Z0' 0 0 6 \
			0 'Raspberry Pi Zero' \
			1 'Raspberry Pi 1' \
			2 'Raspberry Pi 2' \
			3 'Raspberry Pi 3' \
			4 'Raspberry Pi 4' \
			5 'Raspberry Pi 3+' )
	[[ $? == 255 ]] && clear && exit

	if [[ $rpi == 0 || $rpi == 1 ]]; then
		file=ArchLinuxARM-rpi-latest.tar.gz
		[[ $rpi == 0 ]] && rpi=Zero
	elif [[ $rpi == 2 || $rpi == 3 ]]; then
		file=ArchLinuxARM-rpi-2-latest.tar.gz
	elif [[ $rpi == 5 ]]; then
		file=ArchLinuxARM-rpi-3-latest.tar.gz
		rpi=3+
	elif [[ $rpi == 4 ]]; then
		file=ArchLinuxARM-rpi-4-latest.tar.gz
	fi

	yesno '\Z1Connect Wi-Fi on boot?\Z0'
	ans=$?
	[[ $ans == 255 ]] && clear && exit

	if [[ $ans == 0 ]]; then
		ssid=$( inputbox '\Z1Wi-Fi\Z0 - SSID:' )
		[[ $? == 255 ]] && clear && exit

		password=$( inputbox '\Z1Wi-Fi\Z0 - Password:' )
		[[ $? == 255 ]] && clear && exit

		wpa=$( dialog --backtitle "$title" --colors --output-fd 1 \
			--menu '\n\Z1Wi-Fi -Security:\Z1' 0 0 3 \
				1 'WPA' \
				2 'WEP' \
				3 'None' )
		[[ $? == 255 ]] && clear && exit

		if [[ $wpa == 1 ]]; then
			wpa=wpa
		elif [[ $wpa == 2 ]]; then
			wpa=wep
		else
			wpa=
		fi
		wifi="Wi-Fi settings\n\
	 SSID     : \Z1$ssid\Z0\n\
	 Password : \Z1$password\Z0\n\
	 Security : \Z1${wpa^^}\Z0\n"
	fi

	yesno "\Z1Confirm data:\Z0\n\n\
	BOOT path : \Z1$BOOT\Z0\n\
	ROOT path : \Z1$ROOT\Z0\n\
	Target    : \Z1Raspberry Pi $rpi\Z0\n\
	$wifi"
	ans=$?
	if [[ $ans == 255 ]]; then
		clear && exit
	elif [[ $ans == 1 ]]; then
		getData
	fi
}
getData

# download
( wget http://os.archlinuxarm.org/os/$file 2>&1 | \
    stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { \
        print "XXX\n"substr($0,63,3)
        print "\\n\\Z1Download Arch Linux Arm\\Z0\\n"
        print "Time left: "substr($0,74,5)"\nXXX" }' ) | \
    dialog --backtitle "$title" --colors --gauge "\nConnecting ..." 9 50

# checksum
wget -qN http://os.archlinuxarm.org/os/$file.md5
if ! md5sum -c $file.md5; then
    msgbox '\Z1Download incomplete!\Z0'
    exit
fi

# expand
( pv -n $file | bsdtar -C $BOOT --strip-components=2 --no-same-permissions --no-same-owner -xf - boot ) 2>&1 | \
	dialog --backtitle "$title" --colors --gauge "\nExpand to \Z1BOOT\Z0 ..." 9 50
( pv -n $file | bsdtar -C $ROOT --exclude='boot' -xpf - ) 2>&1 | \
	dialog --backtitle "$title" --colors --gauge "\nExpand to \Z1ROOT\Z0 ..." 9 50

infobox "\Z1Be patient.\Z0\n
It may takes 10+ minutes to complete writing\n
from cache to SD card or thumb drive." 7 50
sync

#----------------------------------------------------------------------------
PATH=$PATH:/sbin  # Debian not include /sbin in PATH
partuuidBOOT=$( blkid | grep $( df | grep BOOT | awk '{print $1}' ) | awk '{print $NF}' | tr -d '"' )
partuuidROOT=$( blkid | grep $( df | grep ROOT | awk '{print $1}' ) | awk '{print $NF}' | tr -d '"' )
sed -i "s|/dev/mmcblk0p2|$partuuidROOT|" $BOOT/cmdline.txt
echo "$partuuidBOOT  /boot  vfat  defaults  0  0
$partuuidROOT  /      ext4  defaults  0  0" > $ROOT/etc/fstab

# RPi 0 - fix: kernel panic
[[ $rpi == Zero ]] && echo -e 'force_turbo=1\nover_voltage=2' >> $BOOT/config.txt

# wifi
if [[ $ssid ]]; then
	# profile
	profile="Interface=wlan0
Connection=wireless
IP=dhcp
ESSID=\"$ssid\""
	[[ -n $wpa ]] && profile+="
Security=$wpa
Key=$password
"
	echo "$profile" > "$ROOT/etc/netctl/$ssid"

	# enable startup
	pwd=$PWD
	dir=$ROOT/etc/systemd/system/sys-subsystem-net-devices-wlan0.device.wants
	mkdir -p $dir
	cd $dir
	ln -s ../../../../lib/systemd/system/netctl-auto@.service netctl-auto@wlan0.service
	cd "$pwd"

fi

# get create-rune.sh
wget -qN https://github.com/rern/RuneOS/raw/master/usr/local/bin/create-rune.sh -P $ROOT/usr/local/bin
chmod +x $ROOT/usr/local/bin/create-rune.sh
[[ $? == 0 ]] && rm $0

msgbox "
        Arch Linux Arm for \Z1Raspberry Pi $rpi\Z0\n\
               created successfully.
" 8 58
			   
#----------------------------------------------------------------------------
umount -l $BOOT
umount -l $ROOT

[[ ${partuuidBOOT:0:-3} != ${partuuidROOT:0:-3} ]] && usb=' and USB drive'
msgbox "\Z1Finish.\Z0\n\n
BOOT and ROOT were unmounted.\n
Move micro SD card$usb to RPi.\n
Power on.\n
\Z1Wait 30 seconds\Z0 for boot then press \Z1Enter\Z0 to continue." 12 55

#----------------------------------------------------------------------------
title='Connect to Raspberry Pi'
# scan ip
routerip=$( ip route get 1 | cut -d' ' -f3 )
scanIP() {
	infobox "Scan IP address ..." 5 50
	nmap=$( nmap -sP ${routerip%.*}.* | grep -v 'Starting\|Host is up\|Nmap done' | head -n -1 | sed 's/$/\\n/; s/Nmap.*for/\\nIP  :/; s/Address//' | tr -d '\n' )
	msgbox "\Z1Find IP address of Raspberry Pi:\Z0\n
(Raspberri Pi 4 may listed as Unknown)\n
[arrowdown] = scrolldown\n
$nmap" 50 100

	dialog --backtitle "$title" --colors \
        --ok-label Yes --extra-button --extra-label Rescan --cancel-label No \
        --yesno '\n\Z1Found IP address of Raspberry Pi?\Z0' 7 38
	ans=$?
	if [[ $ans == 3 ]]; then
		scanIP
	elif [[ $ans == 255 ]]; then
		clear && exit
	elif [[ $ans == 1 && -n $rescan ]]; then
		diadog --msgbox '  Try starting over again.' 0 0
		clear && exit
	fi
}
scanIP

if [[ $ans == 1 ]]; then
	yesno '\Z1Connect with Wi-Fi?\Z0'
	if [[ $? == 0 ]]; then
		rescan=1
		msgbox '
- Power off\n
- Connect wired LAN\n
- Power on\n
- Wait 30 seconds
- Press Enter to rescan IP'
		scanIP
	else
		msgbox '
- Power off\n
- Connect a monitor/TV\n
- Power on and observe errors\n
- Try start over again'
		clear && exit
	fi
fi

# connect RPi
rpiip=$( inputbox '\Z1Raspberry Pi IP:\Z0' )
[[ $? == 255 ]] && clear && exit

clear

ssh-keygen -R $rpiip &> /dev/null
ssh alarm@$rpiip
