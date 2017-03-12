#/bin/bash

TAG=`date +%Y%m%d%H%M%S`
WORKDIR=`pwd`
SHDIR=`dirname $0`

exitCommand() {
	rm -rf src
	rm -f main
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

	export GOPATH=$WORKDIR

	CMD="mkdir src"
	runCommand

	if [ -f "kk.ini" ]; then

		for LN in `cat kk.ini`
		do
			if [[ $KK_SECTION = "[GIT]" ]]; then
				KK_KEY=${LN%=*}
				KK_VALUE=${LN#*=}
				URL=${KK_VALUE%:*}
				TAG=${KK_VALUE##*:}

				CMD="git clone $URL src/$KK_KEY"
				runCommand

				CMD="cd src/$KK_KEY"
				runCommand

				CMD="git checkout $TAG"
				runCommand

				CMD="cd $WORKDIR"
				runCommand
			fi
			if [[ $LN = "[GIT]" ]]; then
				KK_SECTION="$LN"
			fi
		done

	fi
	
	CMD="go get -d"
	runCommand

	#build

	CMD="docker pull registry.cn-hangzhou.aliyuncs.com/kk/kk-golang:latest"

	runCommand

	CMD="docker run --rm -v $WORKDIR:/main:rw -v $WORKDIR:/go:rw registry.cn-hangzhou.aliyuncs.com/kk/kk-golang:latest go build"

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

echo -e "\033[32m$WORKDIR\033[0m"

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


