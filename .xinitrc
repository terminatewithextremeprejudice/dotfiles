# Ensure XDG_RUNTIME_DIR is set
if test -z "$XDG_RUNTIME_DIR"; then
    export XDG_RUNTIME_DIR=$(mktemp -d /tmp/$(id -u)-runtime-dir.XXX)
fi

xset -dpms
xset s off -dpms
xset +fp /usr/share/fonts/ &

setxkbmap us &
xhost local:* &
xrdb -load ~/.Xresources &
pulseaudio -d &
gentoo-pipewire-launcher & 
picom --daemon &
nm-applet &
#feh --bg-scale Aflaaie/a_black_and_white_image_of_a_room.jpeg &
sh .sh/status.sh &
exec dbus-launch --exit-with-session dwm 

#while true; do
    # Log stderror to a file 
#    dwm 2> ~/.dwm.log
    # No error logging
    #dwm >/dev/null 2>&1
#done

