#/bin/bash

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

PROJECT=/Users/didi/Documents/ttook/desktop

cd $PROJECT

CMD=./gradlew