#!/bin/bash
##################################################
#             aMule.app bundle creator.          #
##################################################

## This file is part of the aMule Project
##
## Copyright (c) 2004-2011 Angel Vidal ( kry@amule.org )
## Copyright (c) 2003-2011 aMule Team     ( http://www.amule-project.net )
##
## This program is free software; you can redistribute it and/or
## modify it under the terms of the GNU General Public License
## as published by the Free Software Foundation; either
## version 2 of the License, or (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the Free Software
## Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301, USA

SRC_FOLDER="$1"

if [ -z "$SRC_FOLDER" ]; then
    SRC_FOLDER="./"
fi

# Ensure empty directories exist
for app in aMule.app aMuleGUI.app; do
    for dir in Frameworks MacOS SharedSupport SharedSupport/locale; do
        mkdir -p "$app/Contents/$dir"
    done
done

echo "Step 1: Cleaning bundles... "
rm -rf aMule.app/Contents/Frameworks/*
rm -rf aMule.app/Contents/MacOS/*
rm -rf aMule.app/Contents/SharedSupport
rm -rf aMuleGUI.app/Contents/Frameworks/*
rm -rf aMuleGUI.app/Contents/MacOS/*
echo

echo "Step 2.1: Copying aMule to app bundle... "
cp "${SRC_FOLDER}/src/amule" aMule.app/Contents/MacOS/
cp "${SRC_FOLDER}/src/webserver/src/amuleweb" aMule.app/Contents/MacOS/
cp "${SRC_FOLDER}/src/ed2k" aMule.app/Contents/MacOS/
cp "${SRC_FOLDER}/src/amulecmd" aMule.app/Contents/MacOS/
cp "${SRC_FOLDER}/platforms/MacOSX/aMule-Xcode/amule.icns" aMule.app/Contents/Resources/
cp -R "${SRC_FOLDER}/src/webserver" aMule.app/Contents/Resources
find aMule.app/Contents/Resources/webserver \( -name .svn -o -name "Makefile*" -o -name src \) -print0 | xargs -0 rm -rf
echo

echo "Step 2.2: Copying aMuleGUI to app bundle... "
cp "${SRC_FOLDER}/src/amulegui" aMuleGUI.app/Contents/MacOS/
cp "${SRC_FOLDER}/platforms/MacOSX/aMule-Xcode/amule.icns" aMuleGUI.app/Contents/Resources/
echo

echo "Step 3: Installing translations to app bundle... "
orig_dir=$(pwd)
pushd "${SRC_FOLDER}/po" > /dev/null
make install datadir="$orig_dir/aMule.app/Contents/SharedSupport" > /dev/null 2>&1
make install datadir="$orig_dir/aMuleGUI.app/Contents/SharedSupport" > /dev/null 2>&1
popd > /dev/null
echo

echo "Step 4: Copying libs to Frameworks..."
copy_libs() {
    local app=$1
    local binaries=$2
    local bin_dir="$app/Contents/MacOS"
    local frameworks_dir="$app/Contents/Frameworks"
    local copied_libs=()

    for bin in $binaries; do
        for depend_lib in $(otool -L "$bin_dir/$bin" | awk '/\/opt\/homebrew\// {print $1}'); do
            if ! printf '%s\n' "${copied_libs[@]}" | grep -qxF "$depend_lib"; then
                if [ ! -f "$frameworks_dir/$(basename "$depend_lib")" ]; then
                    cp "$depend_lib" "$frameworks_dir"
                    echo "Copied: $depend_lib -> $frameworks_dir"
                fi
                copied_libs+=("$depend_lib")
            fi
        done
    done

    find "$frameworks_dir" -type f | while IFS= read -r lib; do
        for depend_lib in $(otool -L "$lib" | awk '/\/opt\/homebrew\// {print $1}'); do
            if ! printf '%s\n' "${copied_libs[@]}" | grep -qxF "$depend_lib"; then
                if [ ! -f "$frameworks_dir/$(basename "$depend_lib")" ]; then
                    cp "$depend_lib" "$frameworks_dir"
                    echo "Copied: $depend_lib -> $frameworks_dir"
                fi
                copied_libs+=("$depend_lib")
            fi
        done
    done
}
copy_libs "aMule.app" "amule amuleweb ed2k amulecmd"
copy_libs "aMuleGUI.app" "amulegui"
find aMule.app/Contents/Frameworks -type f -exec chmod 755 {} \;
find aMuleGUI.app/Contents/Frameworks -type f -exec chmod 755 {} \;
echo

echo "Step 5: Update libs path link..."
update_libs() {
    local app=$1
    local binaries=$2
    local bin_dir="$app/Contents/MacOS"
    local frameworks_dir="$app/Contents/Frameworks"

    for bin in $binaries; do
        for depend_lib in $(otool -L "$bin_dir/$bin" | awk '/\/opt\/homebrew\// {print $1}'); do
            install_name_tool -change "$depend_lib" @executable_path/../Frameworks/$(basename "$depend_lib") "$bin_dir/$bin"
        done
        echo "Updated: $bin_dir/$bin"
    done

    find "$frameworks_dir" -type f | while IFS= read -r lib; do
        install_name_tool -id @executable_path/../Frameworks/$(basename "$lib") "$lib" 2>/dev/null
        for depend_lib in $(otool -L "$lib" | awk '/\/opt\/homebrew\// {print $1}'); do
            install_name_tool -change "$depend_lib" @executable_path/../Frameworks/$(basename "$depend_lib") "$lib" 2>/dev/null
        done
        echo "Updated: $frameworks_dir/$(basename "$lib")"
    done
}
update_libs "aMule.app" "amule amuleweb ed2k amulecmd"
update_libs "aMuleGUI.app" "amulegui"
echo

echo "Step 6: Codesign..."
sign() {
    local app=$1
    local binaries=$2
    local bin_dir="$app/Contents/MacOS"
    local frameworks_dir="$app/Contents/Frameworks"

    for bin in $binaries; do
        codesign -f -s - "$bin_dir/$bin" 2>/dev/null
        echo "Signed: $bin_dir/$bin"
    done

    find "$frameworks_dir" -type f | while IFS= read -r lib; do
        codesign -f -s - "$lib" 2>/dev/null
        echo "Signed: $frameworks_dir/$lib"
    done
}
sign "aMule.app" "amule amuleweb ed2k amulecmd"
sign "aMuleGUI.app" "amulegui"
echo

echo "Done."
