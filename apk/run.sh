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
echo "FLAVOR: $FLAVOR"
echo "DEBUG: $DEBUG"

for LN in `cat $SHDIR/env.ini`
do
	if [[ $KK_SECTION = "[ENV]" ]]; then
		KK_KEY=${LN%=*}
		KK_VALUE=${LN#*=}
		CMD="export $KK_KEY=$KK_VALUE"
		runCommand
		continue
	fi
	if [[ $LN = "[ENV]" ]]; then
		KK_SECTION="$LN"
	fi
done

if [[ $DEBUG = "1" ]]; then
	CONFIG=Debug
else
	CONFIG=Release
fi

if [ -n "$GIT" ]; then

	URL=${GIT%:*}
	T=${GIT##*:}

	CMD="git clone $URL main"
	runCommand

	CMD="cd main"
	runCommand

	CMD="git checkout $T"
	runCommand

	WORKDIR=`pwd`

	if [[ $FLAVOR = "" ]]; then
		CMD="fir build_apk $PROJECT -p -T $FIR_TOKEN"
	else
		CMD="fir build_apk $PROJECT -f $FLAVOR -p -T $FIR_TOKEN"
	fi
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


