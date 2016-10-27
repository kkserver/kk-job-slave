#/bin/bash

WORKDIR=`pwd`
TAG=`date +%Y%m%d%H%M%S`
SHDIR=`dirname $0`

MAVEN_DIR="$WORKDIR/../../maven"

exitCommand() {
	if [[ $"GIT_TAG" ]]; then
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

#MAVEN_GROUPID=
#MAVEN_ARTIFACTID=
#AAR_NAME=
#DEBUG=

echo "GIT: $GIT"
echo "MAVEN_GROUPID: $MAVEN_GROUPID"
echo "MAVEN_ARTIFACTID: $MAVEN_ARTIFACTID"
echo "AAR_NAME: $AAR_NAME"
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

	if [[ "$DEBUG" ]]; then
		CMD="./gradlew assembleDebug"
		AAR_FNAME="$AAR_NAME-debug.aar"
	else
		CMD="./gradlew assembleRelease"
		AAR_FNAME="$AAR_NAME-debug.aar"
	fi
	runCommand

	if [ ! -d "$MAVEN_DIR/$MAVEN_GROUPID" ]; then
		mkdir "$MAVEN_DIR/$MAVEN_GROUPID"
	fi

	if [ ! -d "$MAVEN_DIR/$MAVEN_GROUPID/$MAVEN_ARTIFACTID" ]; then
		mkdir "$MAVEN_DIR/$MAVEN_GROUPID/$MAVEN_ARTIFACTID"
	fi

	if [ ! -d "$MAVEN_DIR/$MAVEN_GROUPID/$MAVEN_ARTIFACTID/$TAG" ]; then
		mkdir "$MAVEN_DIR/$MAVEN_GROUPID/$MAVEN_ARTIFACTID/$TAG"
	fi

	CMD="cp ./build/outputs/aar/$AAR_FNAME $MAVEN_DIR/$MAVEN_GROUPID/$MAVEN_ARTIFACTID/$TAG/$AAR_NAME-$TAG.aar"
	runCommand

	echo "[OK] TAG: $TAG"

	exitCommand


else
	echo "[FAIL] 未找到 GIT 地址"
	exit 5
fi
