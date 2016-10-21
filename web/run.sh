#/bin/bash


export STATIC="./static"
export VIEW="./@app"

if [ ! "$STATIC_PATTERN" ]; then
	STATIC_PATTERN="(\.min\.css$)|(\.min\.js$)|(/fontello/((css)|(font))/)"
fi


TAG=`date +%Y%m%d%H%M%S`
WORKDIR=`pwd`

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

buildProject() {

	#static compressor

	if [ -d "$HOME/.kk-shell" ]; then
		cd "$HOME/.kk-shell"
		git pull origin master
		cd $WORKDIR
	else
		git clone http://github.com/kkserver/kk-shell $HOME/.kk-shell
		chmod +x $HOME/.kk-shell/web/build.sh
		chmod +x $HOME/.kk-shell/web/view.py
		chmod +x $HOME/.kk-shell/oss/upload.py
	fi

	CMD="$HOME/.kk-shell/web/build.sh"
	runCommand

	#docker
	CMD="docker build -t $PROJECT:$TAG ."
	runCommand

	CMD="docker push $PROJECT:$TAG"
	runCommand

	CMD="docker tag $PROJECT:$TAG $PROJECT:latest"
	runCommand

	CMD="docker push $PROJECT:latest"
	runCommand

	CMD="git tag $TAG"
	runCommand

	CMD="git push origin $TAG"
	runCommand
	
}

echo -e "\033[31m$WORKDIR\033[0m"

#go


echo "GIT: $GIT"
echo "PROJECT: $PROJECT"

if [ -n "$GIT" ]; then

	if [ -n "$PROJECT" ]; then

		URL=${GIT%:*}
		T=${GIT##*:}

		CMD="git clone $URL main"
		runCommand

		CMD="cd main"
		runCommand

		CMD="git checkout $T"
		runCommand

		WORKDIR=`pwd`
		buildProject

		echo "[OK] TAG: $TAG"

		exitCommand

	else 
		echo "[FAIL] 未找到 PROJECT 地址, docker 镜像地址"
		exit 4
	fi

else
	echo "[FAIL] 未找到 GIT 地址"
	exit 5
fi

