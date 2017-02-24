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
echo "SRC_PATH: $SRC_PATH"
echo "ALIAS: $ALIAS"

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

	if [ -n "$SRC_PATH" ]; then
		export STATIC=$SRC_PATH
	else
		export STATIC="."
	fi

	if [ -d "$HOME/.kk-shell" ]; then
		cd "$HOME/.kk-shell"
		git pull origin master
		cd $WORKDIR
	else
		git clone http://github.com/kkserver/kk-shell $HOME/.kk-shell
	fi

	chmod +x $HOME/.kk-shell/web/build.sh
	chmod +x $HOME/.kk-shell/web/view.py
	chmod +x $HOME/.kk-shell/oss/upload.py

	CMD="$HOME/.kk-shell/web/build.sh"
	runCommand

	CMD="$HOME/.kk-shell/oss/upload.py $ALIAS"
	runCommand

	echo "[OK] TAG: $TAG"

	GIT_TAG=

	exitCommand


else
	echo "[FAIL] 未找到 GIT 地址"
	exit 5
fi
