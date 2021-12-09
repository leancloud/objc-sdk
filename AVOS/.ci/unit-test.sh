#!/bin/bash
export LANG="en_US.UTF-8"

DIR_ROOT=$(pwd)
UnitTestInfoFile=${DIR_ROOT}/.ci/UnitTestParser/unitTestInfo.rb
TestCoverageFile=${DIR_ROOT}/.ci/UnitTestParser/targetCoverage.rb

UnitTestDir=${DIR_ROOT}/unittest

UnitTestReportFile=${DIR_ROOT}/testreport.txt

XCResultFile=${UnitTestDir}/Test.xcresult
CoverageJson=${UnitTestDir}/CoverageJson.json

TestInfoResultFile=${UnitTestDir}/testResult.txt
TestInfoFile=${UnitTestDir}/testInfo.txt
CoverageResultFile=${UnitTestDir}/coverage.html
CoverageFile=${UnitTestDir}/coverage.txt

deleteFile(){
    echo $1
    if [ -f $1 ] || [ -d $1 ]; then
    echo "delete"
    rm -rf $1
    fi
}

#cd .ci/
#result_thread=`python3 -c 'import slack_bot; print(slack_bot.sendMessage(content="TapSDK iOS UnitTest Results -> <'${CI_JOB_URL}'|Job URL>"))'`
echo ${result_thread}
#cd ..

unittest(){
    deleteFile ${UnitTestDir}
    deleteFile ${DIR_ROOT}/tmpCov.txt
    xcodebuild test -scheme $1 -destination 'platform=iOS Simulator,name=iPhone 12' -enableCodeCoverage YES -configuration Debug -resultBundlePath "${XCResultFile}"
    ruby ${UnitTestInfoFile} --xcresult-path=${XCResultFile} --output-file=${TestInfoResultFile} > ${TestInfoFile}

    xcrun xccov view --report --json ${XCResultFile} > ${CoverageJson}
    ruby ${TestCoverageFile} --cov-json-path=${CoverageJson} --output-file=${CoverageResultFile} >> ${TestInfoFile}

    echo "Module ${1}\n" >> ${UnitTestReportFile}
    cat ${TestInfoFile} >> ${UnitTestReportFile}
}

rm ${UnitTestReportFile}

unittest LeanCloudObjcTests

covReport=`cat ${UnitTestReportFile}`

echo ${covReport}

curl -X POST \
  -H "X-LC-Id: VBvR5IDylV2gVzvSKP" \
  -H "X-LC-Key: 5OPjqwu3VnrRYlUzMwHsZM1wLO2VtLPPNCmodPjS" \
  -H "Content-Type: application/json" \
  -d "{\"module\": \"LC Storage SDK(Objective-C)\",\"result\": \"${covReport}\"}" \
  https://vbvr5idy.cloud.tds1.tapapis.cn/1.1/classes/TapTestCovReport

#cd .ci/
#python3 -c 'import slack_bot; print(slack_bot.sendMessage(file="'${UnitTestReportFile}'",thread="'${result_thread}'"))'
#cd ..

pwd
