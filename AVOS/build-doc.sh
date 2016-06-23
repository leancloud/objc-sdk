# # make sure you remove all build folders before running this command.
# #rm -rf release-frameworks/
# #rm -rf ui-release-frameworks/
# #rm -rf build

branch=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')

# you can pass a path to the script, eg: ./deploy.sdk.sh ~/Travis/path/to/git/sdk
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

sdk_path=$git_path/iOS/release-$branch

cloud_path=$sdk_path/AVOSCloud.framework/Headers
sns_path=$sdk_path/AVOSCloudSNS.framework/Headers
im_path=$sdk_path/AVOSCloudIM.framework/Headers
crashreport_path=$sdk_path/AVOSCloudCrashReporting.framework/Headers

doc_path=~/Documents/AVOSCloudDoc/api/iOS

rm -rf ./doc
rm -rf $doc_path

#we should doc only the headers in our public SDK 
appledoc=`which appledoc`
$appledoc -o ./doc --project-name "LeanCloud SDK"  --project-company "LeanCloud, Inc" --company-id LeanCloud -v $branch -h \
	--no-install-docset \
	--no-create-docset \
	--ignore $ui_path/SinaWeibo.h \
	--ignore $ui_path/SinaWeiboRequest.h \
	--include AVConstants.html \
 	   $cloud_path $sns_path $im_path $crashreport_path

#inject the Error code Doc
inject_line='<ul><li><a\ href="docs\/AVConstants.html">AVOSCloud\ Error\ Code<\/a><\/li><ul>'
eval "sed -i '' 's/Constant\ References<\/h2>/Constant\ References<\/h2>${inject_line}/' doc/html/index.html"

mv doc/html $doc_path
