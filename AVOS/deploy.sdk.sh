#!/bin/sh

test -f common.function && source common.function || exit 2

branch=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')


if [ -z "$version" ] ; then
    version=$branch
fi

# you can pass a path to the script, eg: ./build-framework.sh ~/Travis/path/to/git/sdk
if [[ "$1" =~ (.+) ]]; then
  git_path=$1

# or you will also to be accepted by writing the path to a file named `deploy_gitpath.txt`
# and pls ignore the file in this git repo in case
elif test -e "deploy_gitpath.txt";then
  git_path=`cat deploy_gitpath.txt`

#default path for zzeng
else
  git_path="/Users/zhuzeng/git/projects/avoscloud-sdk"
fi

output_path=${git_path}/iOS/
new_version_path=${output_path}/release-$version

echo "Git Path to $git_path, current Branch is $version"

echo "#define USER_AGENT @\"AVOS Cloud iOS-$version SDK\"" > AVOSCloud/UserAgent.h
echo "#define SDK_VERSION @\"$version\"" >> AVOSCloud/UserAgent.h

rm -rf ~/Library/Developer/Xcode/DerivedData/paas*

rm -rf $new_version_path
mkdir -p $new_version_path

echo "======= Build AVOSCloud ========"
sh +x build-framework.sh > /tmp/build.log || fail_and_exit "$0"
cat /tmp/build.log | grep -i '^\*.+\*$'


# echo "======= Build AVOSCloudUI ========"
# sh +x build-avoscloud-ui-framework.sh > /tmp/build.log || fail_and_exit "$0"
# cat /tmp/build.log | grep -i '^\*.+\*$'

echo "======= Build AVOSCloudSNS ========"
sh +x build-avoscloudsns-framework.sh > /tmp/build.log || fail_and_exit "$0"
cat /tmp/build.log | grep -i '^\*.+\*$'

echo "======= Build Finish, now copy ======="

mv release-frameworks/Release-universal/*.framework $new_version_path
# mv ui-release-frameworks/Release-universal/*.framework $new_version_path
mv sns-release-frameworks/Release-universal/*.framework $new_version_path

rm -rf release-frameworks
# rm -rf ui-release-frameworks
rm -rf sns-release-frameworks

echo "======= Update podspec ======="
echo 'update Podspec to current version'

cp AVOSCloud.podspec ${new_version_path}/
cp AVOSCloudSNS.podspec ${new_version_path}/
cd ${new_version_path}

if [[ $version == beta || $version == feature ]]; then
	version_number="$(date +"%y%m%d.%H%M")"
	echo "This Beta Release-${version_number}"

	eval "sed -i '' 's/s\.version .*\"/s.version        = \"${version_number}\"/' AVOSCloud.podspec"
	eval "sed -i '' 's/s\.version .*\"/s.version        = \"${version_number}\"/' AVOSCloudSNS.podspec"

	eval "sed -i '' 's/release-v#{s\.version}/release-beta/' AVOSCloud.podspec"
	eval "sed -i '' 's/release-v#{s\.version}/release-beta/' AVOSCloudSNS.podspec"

else
	echo 'This is Offical Final Release'
	eval "sed -i '' 's/s\.version .*\"/s.version        = \"${version#*v}\"/' AVOSCloud.podspec"
	eval "sed -i '' 's/s\.version .*\"/s.version        = \"${version#*v}\"/' AVOSCloudSNS.podspec"

fi

echo "All done, take a look at ${output_path}"
open ${new_version_path}

#cp -r release-frameworks/Release-universal/ /Users/zhuzeng/git/projects/avoscloud-sdk/iOS/beta
#cp -r ui-release-frameworks/Release-universal/ /Users/zhuzeng/git/projects/avoscloud-sdk/iOS/beta
