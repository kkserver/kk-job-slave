#/bin/bash

TAG=`date +%Y%m%d%H%M%S`
WORKDIR=`pwd`
SHDIR=`dirname $0`

exitCommand() {
	exit $1
}

runCommand() {
	echo $CMD
	$CMD
	if [ $? -ne 0 ]; then
		echo "[FAIL] $CMD"
		exitCommand 3
	fi 
}

echo -e "\033[32m$WORKDIR\033[0m"

#go

echo "GIT: $GIT"
echo "PROJECT: $PROJECT"
echo "SCHEME: $SCHEME"
echo "DEBUG: $DEBUG"

if [ "$DEBUG" ]; then
	for LN in `cat $SHDIR/options.ini`
	do
		if [[ $KK_SECTION = "[DEBUG]" ]]; then
			if [[ $LN = "[RELEASE]" ]]; then
				break
			fi
			KK_KEY=${LN%=*}
			KK_VALUE=${LN#*=}
			CMD="export $KK_KEY=$KK_VALUE"
			runCommand
			continue
		fi
		if [[ $LN = "[DEBUG]" ]]; then
			KK_SECTION="$LN"
		fi
	done
	CONFIG=Debug
else
	for LN in `cat $SHDIR/options.ini`
	do
		if [[ $KK_SECTION = "[RELEASE]" ]]; then
			if [[ $LN = "[DEBUG]" ]]; then
				break
			fi
			KK_KEY=${LN%=*}
			KK_VALUE=${LN#*=}
			CMD="export $KK_KEY=$KK_VALUE"
			runCommand
			continue
		fi
		if [[ $LN = "[RELEASE]" ]]; then
			KK_SECTION="$LN"
		fi
	done
	CONFIG=Release
fi

if [ -n "$GIT" ]; then

	URL=${GIT%:*}
	T=${GIT##*:}

	CMD="git clone $URL main"
	runCommand

	CMD="cd main"
	runCommand

	WORKDIR=`pwd`

	CMD="git checkout $T"
	runCommand

	CMD="cd $PROJECT"
	runCommand

	if [ -f "Podfile" ]; then
		CMD="pod install"
		runCommand
	fi

	if [ -f "$SCHEME.xcworkspace" ]; then
		CMD="xcodebuild -workspace $SCHEME.xcworkspace -scheme $SCHEME -configuration $CONFIG CODE_SIGN_IDENTITY=$IDENTITY -sdk iphoneos" 
		runCommand
	else
		CMD="xcodebuild -scheme $SCHEME -configuration $CONFIG CODE_SIGN_IDENTITY=$IDENTITY -sdk iphoneos" 
		runCommand
	fi

	CMD="xcrun -sdk iphoneos PackageApplication -v build/$SCHEME.app -o $OUTDIR/$SCHEME.ipa"
	runCommand

	CMD="fir p build/$SCHEME.ipa -T $FIR_TOKEN"
	runCommand

	CMD="git tag $TAG"
	runCommand

	CMD="git push origin $TAG"
	runCommand

	echo "[OK] TAG: $TAG"

	exitCommand

else
	echo "[FAIL] 未找到 GIT 地址"
	exit 5
fi


