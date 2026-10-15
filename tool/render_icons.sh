#!/bin/sh
# Renders assets/icon/icon.svg into the PNG launcher icons Android < 8 uses
# (newer Android uses the vector adaptive icon in res/mipmap-anydpi-v26).
# Needs rsvg-convert (librsvg2-tools). Run from the project root after
# changing the SVG.
set -e
res=android/app/src/main/res
for pair in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  rsvg-convert -w "${pair#*:}" -h "${pair#*:}" assets/icon/icon.svg \
    -o "$res/mipmap-${pair%%:*}/ic_launcher.png"
done
