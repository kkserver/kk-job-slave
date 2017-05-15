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

		CMD="./gradlew build"
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


