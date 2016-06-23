#!/bin/bash

test -f common.function && source common.function || exit 2

branch=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
if [ -z "$version" ] ; then
    version=$branch
fi
if [[ "$1" =~ (.+) ]]; then
  git_path=$1
fi
new_version_path="${git_path}/iOS/release-$version"
rm -rf $new_version_path
mkdir -p $new_version_path

# clean build data
test -d build && rm -rf build
#rm -rf ~/Library/Developer/Xcode/DerivedData/paas*

echo "#define USER_AGENT @\"AVOS Cloud iOS-$version SDK\"" > AVOSCloud/Utils/UserAgent.h
echo "#define SDK_VERSION @\"$version\"" >> AVOSCloud/Utils/UserAgent.h

echo "======= Build AVOSCloud ========"
cd "$(dirname "$0")"
security unlock-keychain -p "leancloud20150131" ~/Library/Keychains/login.keychain
xcodebuild -target UniversalFramework -configuration Release || fail_and_exit "$0"

echo "======= Build Finish, now copy ======="
mv build/Release-universal/*.framework $new_version_path

echo "======= Update podspec ======="
echo 'update Podspec to current version'
cp AVOSCloud.podspec ${new_version_path}/
cp AVOSCloudIM.podspec ${new_version_path}/
cp AVOSCloudCrashReporting.podspec ${new_version_path}/

echo "Git Path to $git_path, current Branch is $version"

cd ${new_version_path}
if [[ $version == beta || $version == feature ]]; then
	version_number="$(date +"%y%m%d.%H%M")"
	echo "This Beta Release-${version_number}"

	eval "sed -i '' 's/s\.version .*\"/s.version        = \"${version_number}\"/' AVOSCloud.podspec"
	eval "sed -i '' 's/s\.version .*\"/s.version        = \"${version_number}\"/' AVOSCloudIM.podspec"
	eval "sed -i '' 's/s\.version .*\"/s.version        = \"${version_number}\"/' AVOSCloudCrashReporting.podspec"

	eval "sed -i '' 's/release-v#{s\.version}/release-beta/' AVOSCloud.podspec"
	eval "sed -i '' 's/release-v#{s\.version}/release-beta/' AVOSCloudIM.podspec"
	eval "sed -i '' 's/release-v#{s\.version}/release-beta/' AVOSCloudCrashReporting.podspec"

else
	echo 'This is Offical Final Release'
	eval "sed -i '' 's/s\.version .*\"/s.version        = \"${version#*v}\"/' AVOSCloud.podspec"
	eval "sed -i '' 's/s\.version .*\"/s.version        = \"${version#*v}\"/' AVOSCloudIM.podspec"
	eval "sed -i '' 's/s\.version .*\"/s.version        = \"${version#*v}\"/' AVOSCloudCrashReporting.podspec"

fi

echo "All done, take a look at ${git_path}"
#open ${new_version_path}
