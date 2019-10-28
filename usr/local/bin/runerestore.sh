#!/bin/bash

dirdata=/srv/http/data
dirdisplay=$dirdata/display
dirsystem=$dirdata/system

# accesspoint
if [[ -e $dirsystem/accesspoint && -e /etc/hostapd/hostapd.conf && -e $dirsystem/accesspoint-passphrase ]]; then
	echo -e "$bar Enable and restore RPi access point settings ..."
	passphrase=$( cat $dirsystem/accesspoint-passphrase )
	ip=$( cat $dirsystem/accesspoint-ip )
	iprange=$( cat $dirsystem/accesspoint-iprange )
	sed -i -e "/wpa\|rsn_pairwise/ s/^#\+//
		 " -e "s/\(wpa_passphrase=\).*/\1$passphrase/
		 " /etc/hostapd/hostapd.conf
	sed -i -e "s/^\(dhcp-range=\).*/\1$iprange/
		 " -e "s/^\(dhcp-option-force=option:router,\).*/\1$ip/
		 " -e "s/^\(dhcp-option-force=option:dns-server,\).*/\1$ip/
		 " /etc/dnsmasq.conf
fi
# airplay
if [[ -e $dirsystem/airplay && -e /etc/shairport-sync.conf ]]; then
	echo -e "$bar Enable AirPlay ..."
	systemctl enable shairport-sync
fi
# color
if [[ -e $dirdisplay/color ]]; then
	echo -e "$bar Restore color settings ..."
	. /srv/http/addons-functions.sh
	setColor
fi
# fstab
if ls $dirsystem/fstab-* &> /dev/null; then
	echo -e "$bar Restore NAS mounts ..."
	files=( /srv/http/data/system/fstab-* )
	for file in "${files[@]}"; do
		cat $file >> /etc/fstab
	done
fi
# hostname
if [[ -e $dirsystem/hostname ]]; then
	echo -e "$bar Restore host name ..."
	name=$( cat $dirsystem/hostname )
	namelc=$( echo $name | tr '[:upper:]' '[:lower:]' )
	hostname $namelc
	echo $namelc > /etc/hostname
	sed -i "s/^\(ssid=\).*/\1$name/" /etc/hostapd/hostapd.conf &> /dev/null
	sed -i 's/\(zeroconf_name           "\).*/\1$name"/' /etc/mpd.conf
	sed -i "s/\(netbios name = \).*/\1$name/" /etc/samba/smb.conf &> /dev/null
	sed -i "s/^\(name = \).*/\1$name" /etc/shairport-sync.conf &> /dev/null
	sed -i "s/^\(friendlyname = \).*/\1$name/" /etc/upmpdcli.conf &> /dev/null
	sed -i "s/\(.*\[\).*\(\] \[.*\)/\1$namelc\2/" /etc/avahi/services/runeaudio.service
	sed -i "s/\(.*localdomain \).*/\1$namelc.local $namelc/" /etc/hosts
fi
# localbrowser
if [[ -e $dirsystem/localbrowser && -e /usr/bin/chromium ]]; then
	echo -e "$bar Restore browser on RPi settings ..."
	if [[ -e $dirsystem/localbrowser-cursor ]]; then
		sed -i -e "s/\(-use_cursor \).*/\1$( cat $dirsystem/localbrowser-cursor ) \&/
			 " -e "s/\(xset dpms 0 0 \).*/\1$( cat $dirsystem/localbrowser-screenoff ) \&/" /etc/X11/xinit/xinitrc
		cp $dirsystem/localbrowser-rotatecontent /etc/X11/xorg.conf.d/99-raspi-rotate.conf
		if [[ $( cat $dirsystem/localbrowser-overscan ) == 1 ]]; then
			sed -i '/^disable_overscan=1/ s/^#//' /boot/config.txt
		else
			sed -i '/^disable_overscan=1/ s/^/#/' /boot/config.txt
		fi
	fi
	systemctl enable localbrowser
else
	echo -e "$bar Disable browser on RPi ..."
	systemctl disable localbrowser
fi
# login
if [[ -e $dirsystem/login ]]; then
	echo -e "$bar Enable login ..."
	sed -i 's/\(bind_to_address\).*/\1         "localhost"/' /etc/mpd.conf
fi
# mpd.conf
if [[ -e $dirsystem/mpd-* ]]; then
	echo -e "$bar Restore MPD options ..."
	[[ -e $dirsystem/mpd-autoupdate ]] && echo -e "   Enable auto update ..." && sed -i 's/\(auto_update\s*"\).*/\1yes"/' /etc/mpd.conf
	[[ -e $dirsystem/mpd-buffer ]] && echo -e "   Set buffer ..." && sed -i "s/\(audio_buffer_size\s*\"\).*/\1$( cat $dirsystem/mpd-buffer )\"/" /etc/mpd.conf
	[[ -e $dirsystem/mpd-ffmpeg ]] && echo -e "   Enable ffmpeg ..." && sed -i '/ffmpeg/ {n;s/\(enabled\s*"\).*/\1yes"/}' /etc/mpd.conf
	[[ -e $dirsystem/mpd-mixertype ]] && echo -e "   Sey mixer type ..." && sed -i "s/\(mixer_type\s*\"\).*/\1$( cat $dirsystem/mpd-mixertype )\"/" /etc/mpd.conf
	[[ -e $dirsystem/mpd-normalization ]] && echo -e "   Set volume normalization ..." && sed -i 's/\(volume_normalization\s*"\).*/\1yes"/' /etc/mpd.conf
	[[ -e $dirsystem/mpd-replaygain ]] && echo -e "   Set replay gain ..." && sed -i "s/\(replaygain\s*\"\).*/\1$( cat $dirsystem/mpd-replaygain )\"/" /etc/mpd.conf
fi
# netctl profiles
if ls $dirsystem/netctl-* &> /dev/null; then
	echo -e "$bar Restore Wi-Fi connections ..."
	files=( /srv/http/data/system/netctl-* )
	for file in "${files[@]}"; do
		cp "$file" /etc/netctl
	done
fi
# ntp
if [[ -e $dirsystem/ntp ]]; then
	echo -e "$bar Restore NTP servers ..."
	sed -i "s/#*NTP=.*/NTP=$( cat $dirsystem/ntp )/" /etc/systemd/timesyncd.conf
fi
# onboard devices
if [[ ! -e $dirsystem/onboard-audio ]]; then
	echo -e "$bar Disable onboard audio ..."
	sed -i 's/\(dtparam=audio=\).*/\1off/' /boot/config.txt
fi
if [[ -e $dirsystem/onboard-bluetooth ]]; then
	echo -e "$bar Enable onboard Bluetooth ..."
	sed -i '/^#dtoverlay=pi3-disable-bt/ s/^#//' /boot/config.txt
fi
if [[ ! -e $dirsystem/onboard-wlan ]]; then
	echo -e "$bar Disable onboard Wi-Fi ..."
	sed -i '/^dtoverlay=pi3-disable-wifi/ s/^/#/' /boot/config.txt
	systemctl disable netctl-auto@wlan0
fi
# samba
if [[ -e $dirsystem/samba && -e /etc/samba ]]; then
	echo -e "$bar Enable file sharing ..."
	[[ -e $dirsystem/samba-writesd ]] && sed -i '/path = .*USB/ a\tread only = no' /etc/samba/smb.conf
	[[ -e $dirsystem/samba-writeusb ]] && sed -i '/path = .*LocalStorage/ a\tread only = no' /etc/samba/smb.conf
	systemctl enable nmb smb
fi
# timezone
if [[ -e $dirsystem/timezone ]]; then
	echo -e "$bar Set time zone ..."
	ln -sf /usr/share/zoneinfo/$( cat $dirsystem/timezone ) /etc/localtime
fi
# upnp
if [[ -e $dirsystem/upnp && /etc/upmpdcli.conf ]]; then
	echo -e "$bar Enable and restore UPnP settings ..."
	setUpnp() {
		user=( $( cat $dirsystem/upnp-$1user ) )
		pass=( $( cat $dirsystem/upnp-$1pass ) )
		quality=( $( cat $dirsystem/upnp-$1quality 2> /dev/null ) )
		[[ $1 == qobuz ]] && qlty=formatid || qlty=quallity
		sed -i -e "s/#*\($1user = \).*/\1$user/
		 	" -e "s/#*\($1pass = \).*/\1$pass/
		 	" -e "s/#*\($1$qlty = \).*/\1$quality/
			 " /etc/upmpdcli.conf
	}
	[[ -e $dirsystem/upnp-gmusicuser ]] && echo -e "   Enable Google Music ..." && setUpnp gmusic
	[[ -e $dirsystem/upnp-qobuzuser ]] && echo -e "   Enable Qobuz ..." && setUpnp qobuz
	[[ -e $dirsystem/upnp-tidaluser ]] && echo -e "   Enable Tidal ..." && setUpnp tidal
	[[ -e $dirsystem/upnp-spotifyluser ]] && echo -e "   Enable Spotify ..." && setUpnp spotify
	if [[ -e $dirsystem/upnp-ownqueue ]]; then
		sed -i '/^ownqueue/ d' /etc/upmpdcli.conf
	else
		echo -e "   Disable UPnP clear playlist ..."
		sed -i '/^#ownqueue = / a\ownqueue = 0' /etc/upmpdcli.conf
	fi
	systemctl enable upmpdcli
fi

# set permissions and ownership
chown -R http:http "$dirdata"
chown -R mpd:audio "$dirdata/mpd"

echo -e "\n$bar Reboot ..."
shutdown -r now
