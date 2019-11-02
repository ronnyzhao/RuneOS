#!/bin/bash

[[ ! -e /usr/bin/bsdtar ]] && apt install -y bsdtar
[[ ! -e /usr/bin/nmap ]] && apt install -y nmap

tcolor() {
    echo -e "  \e[38;5;6m$1\e[0m" "$2"
}
cols=$( tput cols )

showData() {
    printf %"$cols"s | tr ' ' -
    [[ -n $3 ]] && echo -e "$1\n$2$3" || echo $2 not found.
    printf %"$cols"s | tr ' ' -
}
showROOT() {
    ROOT=$( df | grep ROOT | awk '{print $NF}' )
    showData "$( df -h | grep ROOT )" "ROOT: " "$ROOT"
    [[ -z $ROOT ]] && echo Not mounted or incorrect label. && exit
}
showBOOT() {
    BOOT=$( df | grep BOOT | awk '{print $NF}' )
    showData "$( df -h | grep BOOT )" "BOOT: " "$BOOT"
    [[ -z $BOOT ]] && echo Not mounted or incorrect label. && exit
}
selectRPi() {
    echo -e "\nRaspberry Pi:"
    tcolor 0 'RPi Zero'
    tcolor 1 'RPi 1'
    tcolor 2 'RPi 3+'
    tcolor 3 'RPi 3 and 2'
    tcolor 4 'RPi 4'
    read -rn 1 -p "Select [0-4]: " rpi; echo
    [[ -z $rpi ]] || (( $rpi > 4 )) && echo -e "\nSelect 0, 1, 2, 3 or 4\n" && selectRPi
}

selectRPi

showBOOT
read -rn 1 -p "Confirm path - BOOT [y/N]: " ans; echo
[[ $ans != y && $ans != Y ]] && exit
[[ -n $( ls $BOOT ) ]] && echo $BOOT not empty. && exit

showROOT
read -rn 1 -p "Confirm path - ROOT [y/N]: " ans; echo
[[ $ans != y && $ans != Y ]] && exit
[[ -n $( ls $ROOT | grep -v lost+found ) ]] && echo $ROOT not empty. && exit

echo -e "\nRun ROOT partition on:"
tcolor 1 'Micro SD card'
tcolor 2 'USB drive'
read -rn 1 -p "Select [1/2]: " mode; echo

if [[ $rpi == 0 || $rpi == 1 ]]; then
	file=ArchLinuxARM-rpi-latest.tar.gz
elif [[ $rpi == 2 ]]; then
	file=ArchLinuxARM-rpi-3-latest.tar.gz
elif [[ $rpi == 3 ]]; then
	file=ArchLinuxARM-rpi-2-latest.tar.gz
elif [[ $rpi == 4 ]]; then
	file=ArchLinuxARM-rpi-4-latest.tar.gz
fi

echo -e "\nDownloading ..."
wget -qN --show-progress http://os.archlinuxarm.org/os/$file
[[ $? != 0 ]] && echo -e "\nDownload failed." && exit

echo -e "\nExpand to ROOT ..."
bsdtar xpvf $file -C $ROOT  # if errors - install missing packages
rm $file

echo -e "\nMove /boot to BOOT ..."
mv -v $ROOT/boot/* $BOOT 2> /dev/null

if [[ $mode == 2 ]]; then
	dev=$( df | grep ROOT | awk '{print $1}' )
    uuid=$( /sbin/blkid | grep $dev | cut -d' ' -f3 | tr -d '\"' )
    sed -i "s|/dev/mmcblk0p2|$uuid|" $BOOT/cmdline.txt
    echo "$uuid  /  ext4  defaults  0  0" >> $ROOT/etc/fstab
fi

# RPi 0 - fix: kernel panic
[[ $rpi == 0 ]] && echo -e 'force_turbo=1\nover_voltage=2' >> $BOOT/config.txt

echo
read -rn 1 -p "Setup Wi-Fi auto-connect [y/N]: " ans; echo
if [[ $ans == y || $ans == Y ]]; then
    selectSecurity() {
        echo Security:
        tcolor 1 'WPA'
        tcolor 2 'WEP'
        tcolor 3 'None'
        read -rn 1 -p 'Select [1-3]: ' ans
        [[ -z $ans ]] || (( $ans > 3 )) && echo -e "\nSelect 1, 2 or 3\n" && selectSecurity
        if [[ $ans == 1 ]]; then
            wpa=wpa
        elif [[ $ans == 2 ]]; then
            wpa=wep
        else
            wpa=
        fi
    }
    setCredential() {
        echo
        read -p 'SSID: ' ssid
        read -p 'Password: ' password
        selectSecurity
        echo
        printf %"$cols"s | tr ' ' -
        echo -e "\nSSID: $ssid\nPassword: $password\nSecurity: ${wpa^^}"
        printf %"$cols"s | tr ' ' -
        read -rn1 -p "Confirm and continue? [y/N]: " ans; echo
        [[ $ans != Y && $ans != y ]] && setCredential
    }
    setCredential

    # profile
    profile="Interface=wlan0
    Connection=wireless
    IP=dhcp
    ESSID=\"$ssid\""
    [[ -n $wpa ]] && profile+="Security=$wpa
    Key=$password"
    echo $profile > "$ROOT/etc/netctl/$ssid"

    # enable startup
    dir="$ROOT/etc/systemd/system/netctl@$ssid.service.d"
    mkdir $dir
    echo '[Unit]
    BindsTo=sys-subsystem-net-devices-wlan0.device
    After=sys-subsystem-net-devices-wlan0.device' > "$dir/profile.conf"

    cd $ROOT/etc/systemd/system/multi-user.target.wants
    ln -s ../../../../lib/systemd/system/netctl@.service "netctl@$ssid.service"
    cd
fi

# get write.rune.sh
wget -qN --show-progress https://github.com/rern/RuneOS/raw/master/usr/local/bin/write-rune.sh -P $ROOT/usr/local/bin
chmod +x $ROOT/usr/local/bin/write-rune.sh

umount -l $BOOT && umount -l $ROOT && echo -e "\n$ROOT and $BOOT unmounted.\nMove to Raspberry Pi."
