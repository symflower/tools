#!/bin/bash

export Z3_VERSION=${Z3_VERSION:-$1}
export Z3_VERSION=${Z3_VERSION:-"4.7.1"}

set -exuo pipefail

if which z3 >/dev/null; then
	if z3 --version | grep --quiet $Z3_VERSION; then
		echo "Z3 version $Z3_VERSION already installed."

		exit
	fi
fi

echo "Install Z3 version $Z3_VERSION to $ROOT_DIR."

export BUILD_DIR=`mktemp -d`

function clean_up {
	rm -fr $BUILD_DIR
}
trap clean_up EXIT SIGHUP SIGINT SIGTERM

export BIN_DIR=${BIN_DIR:-$ROOT_DIR/bin}

cd $BUILD_DIR

if [ "$Z3_VERSION" == "master" ]; then
	git clone https://github.com/Z3Prover/z3 .

	export Z3_STATIC_BUILD=1
	export DOTNET_BINDINGS=0
	export JAVA_BINDINGS=0
	export PYTHON_BINDINGS=0

	# Build
	cd $BUILD_DIR
	python scripts/mk_make.py
	cd $BUILD_DIR/build
	make -j 4

	# Copy binaries
	mkdir -p $BIN_DIR
	cp $BUILD_DIR/build/z3 $BIN_DIR
else
	ASSETS=$(curl --silent "https://api.github.com/repos/Z3Prover/z3/releases" | jq ".[] | select(.tag_name == \"z3-$Z3_VERSION\") | .assets")

	if [ -z "$ASSETS" ]; then
		echo "Z3 version $Z3_VERSION does not exist."

		exit 1
	fi

	URL=$(echo $ASSETS | jq --raw-output ".[] | .browser_download_url | select(endswith(\"x64-ubuntu-16.04.zip\"))")

	if [ -z "$URL" ]; then
		echo "Cannot find x64 Ubuntu 16.04 archive in assets."

		exit 1
	fi

	wget $URL
	unzip *.zip
	mv $BUILD_DIR/*/bin/z3 $BIN_DIR
fi
