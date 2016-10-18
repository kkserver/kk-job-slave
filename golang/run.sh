#/bin/sh

TAG=`date +%Y%m%d%H%M%S`
PWD=`pwd`

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

	GOPATH=$PWD

	CMD="go get -d"

	runCommand

	#build

	CMD="docker pull registry.cn-hangzhou.aliyuncs.com/kk/kk-golang:latest"

	runCommand

	CMD="docker run --rm -v $PWD:/main:rw -v $PWD:/go:rw registry.cn-hangzhou.aliyuncs.com/kk/kk-golang:latest go build"

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

}

echo $PWD

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

		PWD=`pwd`
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


