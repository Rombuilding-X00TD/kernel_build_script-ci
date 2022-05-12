#!/bin/bash

 # Script For Building Android arm64 Kernel
 #
 # Copyright (c) 2018-2020 Panchajanya1999 <rsk52959@gmail.com>
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #      http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 #

#Kernel building script

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

err() {
    echo -e "\e[1;41m$*\e[0m"
    exit 1
}

##------------------------------------------------------##
##----------Basic Informations, COMPULSORY--------------##

# The defult directory where the kernel should be placed
KERNEL_DIR=$PWD

# The name of the Kernel, to name the ZIP
KERNEL="halium"

# Kernel zip name type
TYPE="stable"

# The name of the device for which the kernel is built
MODEL="Max Pro M1"

# The codename of the device
DEVICE="X00TD"

# Kernel revision
KERNELTYPE=normal

# The defconfig which should be used. Get it from config.gz from
# your device or check source
DEFCONFIG=X00TD_defconfig

cat /etc/os-release

wget http://launchpadlibrarian.net/347857292/cpio_2.12+dfsg-6_amd64.deb
dpkg -i cpio_2.12+dfsg-6_amd64.deb
wget http://launchpadlibrarian.net/328605868/xz-utils_5.2.2-1.3_amd64.deb
dpkg -i xz-utils_5.2.2-1.3_amd64.deb
# Show manufacturer info
MANUFACTURERINFO="ASUSTek Computer Inc."

# Kernel revision
KERNELTYPE=normal
KERNELRELEASE=stable

# List the kernel version of each device
VERSION="GE"

# Retrieves branch information
CI_BRANCH=$(git rev-parse --abbrev-ref HEAD)
export CI_BRANCH

# Specify compiler. 
# 'clang'
COMPILER=clang
	if [ $COMPILER = "clang" ]
	then
		# install few necessary packages
		apt-get -y install llvm lld gcc-arm-linux-gnueabi gcc-aarch64-linux-gnu clang android-tools-mkbootimg bc bison build-essential ca-certificates curl flex git kmod libssl-dev libtinfo5 python2 sudo unzip wget xz-utils
	fi

# Clean source prior building. 1 is NO(default) | 0 is YES
INCREMENTAL=1

# Push ZIP to Telegram. 1 is YES | 0 is NO(default)
PTTG=1
	if [ $PTTG = 1 ]
	then
		# Set Telegram Chat ID
		CHATID="-495751416"
	fi

# Generate a full DEFCONFIG prior building. 1 is YES | 0 is NO(default)
DEF_REG=0

# Build dtbo.img (select this only if your source has support to building dtbo.img)
# 1 is YES | 0 is NO(default)
BUILD_DTBO=0

# Sign the zipfile
# 1 is YES | 0 is NO
SIGN=0

# Debug purpose. Send logs on every successfull builds
# 1 is YES | 0 is NO(default)
LOG_DEBUG=0

##------------------------------------------------------##
##---------Do Not Touch Anything Beyond This------------##

# Check if we are using a dedicated CI ( Continuous Integration ), and
# set KBUILD_BUILD_VERSION and KBUILD_BUILD_HOST and CI_BRANCH

## Set defaults first
DISTRO=$(cat /etc/issue)
export token="1719149477:AAFAPPtfNTHh_byVBhDZ_anDQD-ywukzWRc"

## Check for CI
if [ -n "$CI" ]
then
	if [ -n "$CIRCLECI" ]
	then
		export KBUILD_BUILD_VERSION=$CIRCLE_BUILD_NUM
		export KBUILD_BUILD_HOST="CircleCI"
		export CI_BRANCH=$CIRCLE_BRANCH
	fi
	if [ -n "$DRONE" ]
	then
		export KBUILD_BUILD_VERSION=$DRONE_BUILD_NUM
		export KBUILD_BUILD_HOST="DroneCI"
		export CI_BRANCH=$DRONE_BRANCH
	else
		echo "Not presetting Build Version"
	fi
fi

# Check Kernel Version
KERVER=$(make kernelversion)

# Set a commit head
COMMIT_HEAD=$(git log --oneline -1)

# Set Date 
DATE=$(TZ=Asia/Jakarta date +"%Y%m%d-%T")

# Now Its time for other stuffs like cloning, exporting, etc

clone() {
	echo " "
	if [ $COMPILER = "clang" ]
	then
		msg "|| Cloning GCC 4.9 baremetal ||"
		git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b android11-release --depth 1 gcc64
		git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b android11-release --depth 1 gcc32
		git clone https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 -b android11-release --depth 1 
		CLANG_PATH="$KERNEL_DIR/linux-x86/clang-r383902/bin"
		GCC64_DIR=$KERNEL_DIR/gcc64
		GCC32_DIR=$KERNEL_DIR/gcc32
	fi

	msg "|| Cloning Anykernel for X00T ||"
	git clone --depth=1 https://github.com/STRK-ND/AnyKernel3 Anykernel3

	if [ $BUILD_DTBO = 1 ]
	then
		msg "|| Cloning libufdt ||"
		git clone https://android.googlesource.com/platform/system/libufdt "$KERNEL_DIR"/scripts/ufdt/libufdt
	fi
}

##------------------------------------------------------##

exports() {
	export KBUILD_BUILD_USER="iMe"
	export ARCH=arm64
	export SUBARCH=arm64

	if [ $COMPILER = "clang" ]
	then
		echo 'Compiling with clang !'
		KBUILD_COMPILER_STRING=$("$CLANG_PATH"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
		PATH=$GCC64_DIR/bin/:$GCC32_DIR/bin/:$CLANG_PATH/bin:/usr/bin:$PATH

	fi

	export PATH KBUILD_COMPILER_STRING
	export BOT_MSG_URL="https://api.telegram.org/bot$token/sendMessage"
	export BOT_BUILD_URL="https://api.telegram.org/bot$token/sendDocument"
	PROCS=$(nproc --all)
	export PROCS
}

##---------------------------------------------------------##

tg_post_msg() {
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$2" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"

}

##----------------------------------------------------------------##

tg_post_build() {
	#Post MD5Checksum alongwith for easeness
	MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)

	#Show the Checksum alongwith caption
	curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
	-F chat_id="$2"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$3 | <b>MD5 Checksum : </b><code>$MD5CHECK</code>"  
}

##----------------------------------------------------------##

# Function to replace defconfig versioning
setversioning() {
if [[ "$CI_BRANCH" == "main" ]]; then
    # For staging branch
    KERNELNAME="$KERNEL-$DEVICE-$KERNELTYPE-$TYPE-$VERSION-$DATE"
    # Export our new localversion and zipnames
    export KERNELTYPE KERNELNAME
    export ZIPNAME="$KERNELNAME.zip"
else
	# For staging branch
    KERNELNAME="$KERNEL-$DEVICE-$KERNELTYPE-$TYPE-$VERSION1-$DATE"
    # Export our new localversion and zipnames
    export KERNELTYPE KERNELNAME
    export ZIPNAME="$KERNELNAME.zip"
fi
}

##----------------------------------------------------------##

build_kernel() {
	if [ $INCREMENTAL = 0 ]
	then
		msg "|| Cleaning Sources ||"
		make clean && make mrproper && rm -rf out
	fi

	if [ "$PTTG" = 1 ]
 	then
		tg_post_msg "<b>Docker OS: </b><code>$DISTRO</code>%0A<b>Kernel Version : </b><code>$KERVER</code>%0A<b>Date : </b><code>$(TZ=Asia/Jakarta date)</code>%0A<b>Device : </b><code>$MODEL [$DEVICE]</code>%0A<b>Manufacturer : </b><code>$MANUFACTURERINFO</code>%0A<b>Pipeline Host : </b><code>$KBUILD_BUILD_HOST</code>%0A<b>Host Core Count : </b><code>$PROCS</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0a<b>Branch : </b><code>$CI_BRANCH</code>%0A<b>Last Commit : </b><code>$COMMIT_HEAD</code>%0A" "$CHATID"
	fi

	msg "|| Started Compilation ||"

	make O=out $DEFCONFIG
	if [ $DEF_REG = 1 ]
	then
		cp .config arch/arm64/configs/$DEFCONFIG
		git add arch/arm64/configs/$DEFCONFIG
		git commit -m "$DEFCONFIG: Regenerate
					This is an auto-generated commit"
	fi

	BUILD_START=$(date +"%s")

	if [ $COMPILER = "clang" ]
	then
            export CROSS_COMPILE=$KERNEL_DIR/gcc64/bin/aarch64-linux-android-
	  export CROSS_COMPILE_ARM32=$KERNEL_DIR/gcc32/bin/arm-linux-androideabi-
            make -j"$PROCS" O=out \
	          CC=clang \
	          CLANG_TRIPLE=aarch64-linux-gnu- \
		CROSS_COMPILE=aarch64-linux-android- \
		CROSS_COMPILE_ARM32=arm-linux-androideabi-
	fi


	BUILD_END=$(date +"%s")
	DIFF=$((BUILD_END - BUILD_START))

	if [ -f "$KERNEL_DIR"/out/arch/arm64/boot/Image.gz-dtb ] 
	then
		msg "|| Kernel successfully compiled ||"
	elif ! [ -f $KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb ]
	then
		echo -e "Kernel compilation failed, See buildlog to fix errors"
		tg_post_msg "<b>Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds</b>" "$CHATID" 
		exit 1
	fi

	if [ $BUILD_DTBO = 1 ]
	then
		msg "|| Building DTBO ||"
		tg_post_msg "<code>Building DTBO..</code>" "$CHATID"
		python2 "$KERNEL_DIR/scripts/ufdt/libufdt/utils/src/mkdtboimg.py" \
			create "$KERNEL_DIR/out/arch/arm64/boot/dtbo.img" --page_size=4096 "$KERNEL_DIR/out/arch/arm64/boot/dts/qcom/sm6150-idp-overlay.dtbo"
	fi

        echo "sec-cess"

        msg "|| Zipping into a flashable zip ||"
	 cp "$KERNEL_DIR"/out/arch/arm64/boot/Image.gz-dtb Anykernel3/
	if [ $BUILD_DTBO = 1 ]
	then
		cp "$KERNEL_DIR"/out/arch/arm64/boot/dtbo.img Anykernel3/
	fi
	cd Anykernel3 || exit
	zip -r9 "$ZIPNAME" * -x .git README.md

	## Prepare a final zip variable
	ZIP_FINAL="$ZIPNAME"

	if [ "$PTTG" = 1 ]
 	then
		tg_post_build "$ZIP_FINAL" "$CHATID" "Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
	fi
	cd ..

}

##--------------------------------------------------------------##
echo "all"
gen_zip() {
echo "genzip"

}

setversioning
clone
exports
build_kernel
gen_zip

if [ $LOG_DEBUG = "1" ]
then
	tg_post_build "error.log" "$CHATID" "Debug Mode Logs"
fi

##------------------------------------------------------------------##
