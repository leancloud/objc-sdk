#!/bin/bash

test -f common.function && source common.function || exit 2

if hostname | grep -iE '(avos|builder)' > /dev/null 2>&1 ; then
  release_sdk_path="/Users/avos/jenkins/workspace/avoscloud-sdk/"
elif hostname | grep -i hj > /dev/null 2>&1 ; then
  release_sdk_path="/Users/hong/avos/code/avoscloud-sdk"
fi
branch=$(get_current_branch)
if [ x"$branch" = "xmaster" ]; then
  echo "|==> BRANCH CAN NOT BE MASTER ! EXIT"
  exit 1
fi
version=${branch//v/} # cut off character 'v'


if [ "x$1" == "xiOS" ]; then
  cd $release_sdk_path && {
    echo "|==> Prepare $release_sdk_path git repo for iOS"
    git stash && git pull origin master
    echo "|==> Delete $release_sdk_path/iOS/release-${branch} if existed"
    rm -rfv $release_sdk_path/iOS/release-${branch}
  }

  cd -
  #cd iOS/paas/
  test -d ~/Library/Developer/Xcode/DerivedData/ && rm -rf ~/Library/Developer/Xcode/DerivedData/
  # test sdk
  #xcodebuild test -scheme AVOSCloud -sdk iphonesimulator -configuration Release || fail_and_exit $0
  # build ios sdk
   ./build-framework.sh $release_sdk_path || fail_and_exit "$0"
  echo
elif [ "x$1" == "xOSX" ];then
  cd iOS/paas/
  test -d ~/Library/Developer/Xcode/DerivedData/ && rm -rf ~/Library/Developer/Xcode/DerivedData/
  # build OSX sdk
   ./deploy.osx-sdk.sh $release_sdk_path || fail_and_exit "$0"
  echo
else
  echo "Argument \$1 = $1, SHOULD BE IN iOS/OSX, EXIT !"
  exit 1
fi

