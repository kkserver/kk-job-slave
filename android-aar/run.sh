#/bin/bash

WORKDIR=`pwd`
TAG=`date +%Y%m%d%H%M%S`
SHDIR=`dirname $0`

exitCommand() {
	if [[ "$GIT_TAG" = "1" ]]; then
		cd $WORKDIR/main
		CMD="git push origin --delete tag $TAG"
		echo $CMD
		$CMD
		if [ $? -ne 0 ]; then
			echo "[FAIL] $CMD"
			exit 3
		fi 
	fi
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
echo "GIT: $GIT"
echo "DEBUG: $DEBUG"

for LN in `cat $SHDIR/options.ini`
do
	if [[ $KK_SECTION = "[ENV]" ]]; then
		KK_KEY=${LN%=*}
		KK_VALUE=${LN#*=}
		export $KK_KEY=$KK_VALUE
		continue
	fi
	if [[ $LN = "[ENV]" ]]; then
		KK_SECTION="$LN"
	fi
done

if [ -n "$GIT" ]; then


	URL=${GIT%:*}
	T=${GIT##*:}

	CMD="git clone $URL main"
	runCommand

	CMD="cd main"
	runCommand

	CMD="git checkout $T"
	runCommand

	CMD="git tag $TAG"
	runCommand

	CMD="git push origin $TAG"
	runCommand

	GIT_TAG=1

	echo -e "ndk.dir=$ANDROID_NDK_DIR\nsdk.dir=$ANDROID_SDK_DIR" > "./local.properties"
	echo -e "\nRELEASE_REPOSITORY_URL=$RELEASE_REPOSITORY_URL\n" >> "./gradle.properties"

	rm -f build.gradle
	cp $SHDIR/build.gradle build.gradle

	if [[ "$DEBUG" ]]; then
		CMD="./gradlew assembleDebug"
	else
		CMD="./gradlew assembleRelease"
	fi
	runCommand

	CMD="./gradlew uploadArchives"
	runCommand

	echo "[OK] TAG: $TAG"

	GIT_TAG=

	exitCommand


else
	echo "[FAIL] 未找到 GIT 地址"
	exit 5
fi
