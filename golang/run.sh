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

buildProject() {

	export GOPATH=$WORKDIR

	for LN in `cat $SHDIR/options.ini`
	do
		if [[ $KK_SECTION = "[CP]" ]]; then
			if [[ $LN = "[GIT]" ]]; then
				break
			fi
			KK_KEY=${LN%=*}
			KK_VALUE=${LN#*=}
			DIR=$WORKDIR/$KK_VALUE
			CMD="mkdir -p ${DIR%/*}"
			runCommand
			CMD="cp -r $KK_KEY $WORKDIR/$KK_VALUE"
			runCommand
			continue
		fi
		if [[ $LN = "[CP]" ]]; then
			KK_SECTION="$LN"
		fi
	done

	for LN in `cat $SHDIR/options.ini`
	do
		if [[ $KK_SECTION = "[GIT]" ]]; then
			if [[ $LN = "[CP]" ]]; then
				break
			fi
			KK_KEY=${LN%=*}
			KK_VALUE=${LN#*=}
			CMD="cd $WORKDIR/$KK_KEY"
			runCommand
			CMD="git checkout $KK_VALUE"
			runCommand
			CMD="git pull origin $KK_VALUE"
			runCommand
			CMD="cd $WORKDIR"
			runCommand
			continue
		fi
		if [[ $LN = "[GIT]" ]]; then
			KK_SECTION="$LN"
		fi
	done

	CMD="cd $SRC_PATH"
	runCommand

	CMD="go get -d -u"
	runCommand

	#build

	CMD="docker pull registry.cn-hangzhou.aliyuncs.com/kk/kk-golang:latest"

	runCommand

	CMD="docker run --rm -v $WORKDIR/$SRC_PATH:/main:rw -v $WORKDIR:/go:rw registry.cn-hangzhou.aliyuncs.com/kk/kk-golang:latest go build"

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
echo "SRC_PATH: $SRC_PATH"

if [ ! $SRC_PATH ]
then
SRC_PATH=src
fi

if [ -n "$GIT" ]; then

	if [ -n "$PROJECT" ]; then

		URL=${GIT%:*}
		T=${GIT##*:}

		CMD="git clone $URL main/$SRC_PATH"
		runCommand

		CMD="cd main"
		runCommand

		WORKDIR=`pwd`

		echo "mkdir -p $SRC_PATH"
		mkdir -p $SRC_PATH

		CMD="cd $SRC_PATH"
		runCommand

		CMD="git checkout $T"
		runCommand

		CMD="cd $WORKDIR"
		runCommand

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


