#!/usr/bin/env bash

# MPS (mplayer script) Copyright (C) 2022 Marc Carlson

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see https://www.gnu.org/licenses/

music=~/Music
eq_settings="2:6:2:1:1:0:1:2:5:2"

function usage {
echo ""
echo "  MPS - Mplayer script (c) 2022 Marc Carlson"
echo ""
echo "  Usage: mps [options]"
echo ""
echo "  add title <title> - add tracks by title"
echo "  add album <album> - add tracks by album"
echo "  add genre <genre> - add tracks by genre"
echo "  add artist <artist> - add tracks by artist"
echo ""
echo "  play - play tracks in playlist"
echo "  shuffle - play and shuffle tracks in playlist"
echo ""
echo "  showlist - show tracks in playlist"
echo "  pause - pause/unpause music"
echo "  next - play next track in playlist"
echo "  previous - play previous track"
echo "  repeat - repeat the currently playing track once"
echo "  stop - stop playback"
echo "  trackinfo - show info about currently playing track"
echo "  delete <track number> - delete tracks"
echo "  clear - clear playlist"
echo ""
echo "  enable notify - enable notifications"
echo "  disable notify - disable notifications"
echo ""
echo "  enable eq - enable audio equalizer"
echo "  disable eq - disable audio equalizer"
echo ""
}

function get_args {
[ $# -eq 0 ] && usage && exit
while getopts ":h" arg; do
case $arg in
h) usage && exit ;;
esac
done
}

shopt -s nocasematch
shopt -s globstar

type -P mp3info 1>/dev/null
[ "$?" -ne 0 ] && echo "Please install mp3info before using this script." && exit
type -P mplayer 1>/dev/null
[ "$?" -ne 0 ] && echo "Please install mplayer before using this script." && exit
type -P ffmpeg 1>/dev/null
[ "$?" -ne 0 ] && echo "Please install ffmpeg before using this script." && exit
type -P notify-send 1>/dev/null
[ "$?" -ne 0 ] && echo "Please install notify-send before using this script." && exit

if [[ ! -d $music ]]; then echo $music does not exist, edit your music directory in the MPS script. && exit; fi

function genre {
ps -A | grep mplayer | grep -v grep | if grep -q 'shuffle'; then echo cannot add tracks in shuffle mode && exit
else 
if [[ -e /tmp/new ]]; then rm /tmp/new
fi
if pgrep -x mplayer >/dev/null
then for file in $music/**/*.mp3; do if [[ "$(mp3info -p '%g' "$file")" == *"$1"* ]]
then echo $file >> /tmp/playlist && echo $file >> /tmp/new
fi
done
echo "loadlist /tmp/new 2" > /tmp/fifo
else for file in $music/**/*.mp3; do if [[ "$(mp3info -p '%g' "$file")" == *"$1"* ]]
then echo $file >> /tmp/playlist
fi
done
fi
fi
}

function album {
ps -A | grep mplayer | grep -v grep | if grep -q 'shuffle'; then echo cannot add tracks in shuffle mode && exit
else 
if [[ -e /tmp/new ]]; then rm /tmp/new
fi
if pgrep -x mplayer >/dev/null
then for file in $music/**/*.mp3; do if [[ "$(mp3info -p '%l' "$file")" == *"$1"* ]]; then echo $file >> /tmp/playlist && echo $file >> /tmp/new
fi
done
echo "loadlist /tmp/new 2" > /tmp/fifo
else for file in $music/**/*.mp3; do if [[ "$(mp3info -p '%l' "$file")" == *"$1"* ]]; then echo $file >> /tmp/playlist
fi
done
fi
fi
}

function artist {
ps -A | grep mplayer | grep -v grep | if grep -q 'shuffle'; then echo cannot add tracks in shuffle mode && exit
else 
if [[ -e /tmp/new ]]; then rm /tmp/new
fi
if pgrep -x mplayer >/dev/null
then for file in $music/**/*.mp3; do if [[ "$(mp3info -p '%a' "$file")" == *"$1"* ]]; then echo $file >> /tmp/playlist && echo $file >> /tmp/new
fi
done
echo "loadlist /tmp/new 2" > /tmp/fifo
else for file in $music/**/*.mp3; do if [[ "$(mp3info -p '%a' "$file")" == *"$1"* ]]; then echo $file >> /tmp/playlist
fi
done
fi
fi
}

function title {
ps -A | grep mplayer | grep -v grep | if grep -q 'shuffle'; then echo cannot add tracks in shuffle mode && exit
else 
if [[ -e /tmp/new ]]; then rm /tmp/new
fi
if pgrep -x mplayer >/dev/null;
then for file in $music/**/*.mp3; do if [[ "$(mp3info -p '%t' "$file")" == *"$1"* ]]; then echo $file >> /tmp/playlist && echo $file > /tmp/new
fi
done
echo "loadlist /tmp/new 2" > /tmp/fifo
else for file in $music/**/*.mp3; do if [[ "$(mp3info -p '%t' "$file")" == *"$1"* ]]; then echo $file >> /tmp/playlist
fi
done
fi
fi
}

function next {
echo "pausing_keep_force pt_step 1" > /tmp/fifo
}

function previous {
echo "pausing_keep_force pt_step -1" > /tmp/fifo
}

function repeat {
echo loop 2 > /tmp/fifo
}

function pause {
echo "pause" > /tmp/fifo
}

function clear {
if  [ ! -f /tmp/playlist ]; then echo No songs in playlist && exit
fi
rm /tmp/playlist && exit
}

function showlist {
if [ ! -f /tmp/playlist ]; then echo No songs in playlist && exit
fi
if [ -f /tmp/playlist ]; then awk '{print $NF}' FS=/ /tmp/playlist | cut -d . -f 1 && exit
fi
}

function trackinfo {
song=$(cat /tmp/log | grep Playing | sed 's/Playing//g' | sed 's/ //1'| cut -d . -f 1,2 | tail -n 1)
mp3info -p '%y %a - %t %m:%02s\n' "$song"
}

function delete {
if pgrep -x mplayer >/dev/null; then echo cannot delete tracks during playback
else sed -i "$1"'d' /tmp/playlist && exit
fi
}

function stop {
if pgrep -x mplayer  >/dev/null; then
if [[ -f /tmp/log ]]; then rm /tmp/log
pkill mplayer; fi
pid=$(ps -A | grep tail | grep -v grep | grep "tail -n 25 -f /tmp/log" | awk '{print $1}')
kill $pid 2>/dev/null
pid2=$(ps -A | grep tail | grep -v grep | grep "tail -n 24 -f /tmp/log" | awk '{print $1}')
kill $pid2 2>/dev/null
else echo mps already stopped && exit
fi
}

function kill_tail {
while true; do
if pgrep -x mplayer >/dev/null
then
sleep 1
else
pid=$(ps -A | grep tail | grep -v grep | grep "tail -n 25 -f /tmp/log" | awk '{print $1}')
kill $pid 2>/dev/null
pid2=$(ps -A | grep tail | grep -v grep | grep "tail -n 24 -f /tmp/log" | awk '{print $1}')
kill $pid2 2>/dev/null
break
fi
done
}

function play {
if [ ! -f /tmp/playlist ]; then echo No songs in playlist && exit; fi
if pgrep -x mplayer >/dev/null; then echo mplayer already running && exit
else if [[ ! -e /tmp/fifo ]]; then mkfifo /tmp/fifo; fi
( mplayer -slave -input file=/tmp/fifo -playlist /tmp/playlist > /tmp/log 2>&1 & )
fi
}

function shuffle {
if [ ! -f /tmp/playlist ]; then echo No songs in playlist && exit
fi
if pgrep -x mplayer >/dev/null; then echo mplayer already running && exit
else if [[ ! -e /tmp/fifo ]]; then mkfifo /tmp/fifo; fi
( mplayer -slave -input file=/tmp/fifo -shuffle -playlist /tmp/playlist > /tmp/log 2>&1 & )
fi
}

function notify {
if pgrep -x mplayer >/dev/null; then
(tail -n 25 -f /tmp/log  | grep --line-buffered "Playing" |  while read line
do
song=$(cat /tmp/log | grep Playing | sed 's/Playing//g' | sed 's/ //1'| cut -d . -f 1,2 | tail -n 1) 
( ffmpeg -y -i "$song" /tmp/album.jpg > /dev/null 2>&1 & ) 
sleep 0.6
notify-send -i /tmp/album.jpg "Now Playing" "$(mp3info -p '%a - %t' "$song")"
done > /dev/null 2>&1 &)
fi
}

if [[ $1 == "enable" ]] && [[ $2 == "notify" ]]; then 
ps -A | grep -v grep | if grep -q 'tail -n 25 -f /tmp/log'; then echo notify is already enabled && exit
else
notify
kill_tail &
fi
fi

if [[ $1 == "disable" ]] && [[ $2 == "notify" ]]; then
ps -A | grep tail | grep -v grep | if grep -q 'tail -n 25 -f /tmp/log'; then
pid=$(ps -A | grep tail | grep -v grep | grep "tail -n 25 -f /tmp/log" | awk '{print $1}')
kill $pid 2>/dev/null
else echo notify is already disabled
fi
fi

if [[ $1 == "enable" ]] && [[ $2 == "eq" ]]
then
if pgrep -x mplayer >/dev/null
then
ps -A | grep -v grep | if grep -q 'tail -n 24 -f /tmp/log'; then echo eq is already enabled && exit
else (tail -n 24 -f /tmp/log | grep --line-buffered "Playing" | while read line
do
echo af_add equalizer="$eq_settings" > /tmp/fifo
done > /dev/null 2>&1 &)
kill_tail &
fi
fi
fi

if [[ $1 == "disable" ]] && [[ $2 == "eq" ]]
then
ps -A | grep tail | grep -v grep | if grep -q 'tail -n 24 -f /tmp/log'; then echo af_clr > /tmp/fifo
pid2=$(ps -A | grep tail | grep -v grep | grep "24" | awk '{print $1}')
kill $pid2 2>/dev/null
else
echo eq is already disabled && exit
fi
fi

get_args $@

list='genre album artist title'
for item in $list;
do
if [[ $1 == "add" ]] && [[ $2 == "$item" ]] && [[ "$3" == $3 ]]
then
$2 $3 && exit
fi
done

list='play shuffle pause trackinfo next previous repeat stop delete clear showlist'
for item in $list;
do
if [[ $1 == "$item" ]]
then
$1 $2 && exit
fi
done
