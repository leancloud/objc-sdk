#!/bin/bash -v

# 此脚本需要在 ./AVOS 目录下运行。Jenkins 中添加 cd AVOS && bash build-doc-new.sh
if [ "$1" != "--skip-xcodebuild" ]; then
	security unlock-keychain -p "leancloud20150131" ~/Library/Keychains/login.keychain
	xcodebuild -project AVOS.xcodeproj -target UniversalFramework -configuration Release
fi

[ "$2" = "--skip-push-doc" ] && skip_push_doc=1 || skip_push_doc=0

sdk_path=./build/Release-universal
cloud_path=$sdk_path/AVOSCloud.framework/Headers
im_path=$sdk_path/AVOSCloudIM.framework/Headers

branch=$(git branch | grep "^*" | awk '{print $2}')

if hostname | grep -iE '(avos|builder)' > /dev/null 2>&1 ; then
	release_doc_path="/Users/avos/jenkins/workspace/api-docs"
else
	release_doc_path="/Users/lzw/avos/api-docs" #locally
fi

rm -rf ./doc

#we should doc only the headers in our public SDK 
/usr/local/bin/appledoc -o ./doc --project-name "LeanCloud SDK"  --project-company "LeanCloud, Inc" --company-id LeanCloud -v $branch -h \
	--no-install-docset \
	--no-create-docset \
	--keep-undocumented-objects \
	--keep-undocumented-members \
	--include AVConstants.html \
 	   $cloud_path $im_path

inject_line='<ul><li><a\ href="docs\/AVConstants.html">AVOSCloud\ Error\ Code<\/a><\/li><ul>'
eval "sed -i '' 's/Constant\ References<\/h2>/Constant\ References<\/h2>${inject_line}/' doc/html/index.html"

html_path=`pwd`/doc/html

if [ ! -d "$html_path" ]; then 
	echo "apple doc build failed and exit"
	exit
fi

if [ ! -d "$release_doc_path/api/iOS" ]; then 
	echo "$release_doc_path/api/iOS not exist and exit"
	exit
fi

if [ ! skip_push_doc ]; then 
 cd $release_doc_path && {
	git pull origin master --verbose
	rm -rf $release_doc_path/api/iOS
	cp -r $html_path $release_doc_path/api/iOS
	git add -A api/iOS/
	git commit -m "[JENKINS] iOS API doc update version ${branch}"
	git push origin master --verbose #comment it when test locally 
  } && \
 echo "COMMIT TO DOCS REPO DONE !" || \
 fail_and_exit "API DOC UPDATE FAILUR"
fi

