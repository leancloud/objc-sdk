## 说明

> 苹果在**Xcode11**版本中对单元测试结果文件(*.xcresult*文件)及相关命令(`xccov view`等)有较大更新，请参考 [https://developer.apple.com/documentation/xcode_release_notes/xcode_11_release_notes?language=objc](https://developer.apple.com/documentation/xcode_release_notes/xcode_11_release_notes?language=objc)。主要的变化是   *.xcresult* 文件中**不再包含** *.xccovarchive* 文件。

## 目录

- [单元测试基础](#单元测试基础)
- [单元测试概况统计](#单元测试概况统计)

<br/>

## 单元测试基础

### 单元测试命令

执行如下命令即可进行单元测试。单元测试过程中产生的文件存放在`BUILD_DIR`目录。

```objective-c
# resultBundleVersion 为可选参数，为了防止后续版本更新导致结果文件变化，建议加上这个参数

# for xcodeproj
xcodebuild test -project Demo.xcodeproj -scheme Demo -derivedDataPath "${BUILD_DIR}/" -destination "${SIMULATOR_PLATFORM}" -resultBundlePath "${XCRESULT_PATH}" -resultBundleVersion 3

# for xcworkspace
xcodebuild test -workspace Demo.xcworkspace -scheme Demo -derivedDataPath "${BUILD_DIR}/" -destination "${SIMULATOR_PLATFORM}" -resultBundlePath "${XCRESULT_PATH}" -resultBundleVersion 3
```

`SIMULATOR_PLATFORM`指定使用的模拟器类型，如。不同机器上可用的模拟器类型不同，如 *platform=iOS Simulator,OS=13.4,name=iPhone 11*，不同机器上可用的模拟器类型不尽相同，可以通过如下命令获取可用的模拟器列表

```
xcrun simctl list
```

`XCRESULT_PATH`指定单元测试结果文件（*.xcresult*文件）的存放路径，这个参数是Xcode11的命令行工具中新增加的，便于直接获取到结果文件。使用Xcode10及之前版本时，我们必须去*BUILD_DIR*对应的目录中找这个文件。（其实在Xcode11中，.xcresult文件在*BUILD_DIR*对应的目录中也会有一份拷贝，不过当然是直接指定结果文件路径来的方便。）



### 单元测试结果

单元测试执行完成之后，就可以在`XCRESULT_PATH`找到产生的结果文件，也就是 *.xccresult* 文件。该文件打开后的目录格式为：

```
.
├── Data/
│   ├── data0~xxx
│   └── data0~xxx
│ 
└── Info.plist

```

通过解析这些文件，就可以获得单元测试概况、代码覆盖率等基本的单元测试数据。  
> *.xcresult* 文件也支持直接在Xcode中打开，双击打开后就可以在Xcode中看到本次单元测试的详情。

## 单元测试概况统计

单元测试概况统计需要使用官方提供的`xcrun xcresulttool`工具。  

首先需要获取到出json格式的数据，并从json数据中解析出获取单元测试报告所需的**id**：

```shell
# 解析成json数据，便于下一步获取id
xcrun xcresulttool get --format json --path path/to/xcresult_file 
```

从json数据中获取id需要一连串复杂的json字段解析，这里我参考了[fastlane的xcresult解析脚本](https://github.com/fastlane-community/trainer/blob/307d52bd6576ceefc40d3f57e34ce3653af10b6b/lib/trainer/xcresult.rb)，不再自己重新写一遍id提取逻辑。  

获取到id之后，就能进一步拿到详细的单元测试报告数据。 

```shell
xcrun xcresulttool get --format json --path path/to/xcresult_file --id $id
```

执行上面的命令之后，又可以获取到了一份json数据，继续解析这份json数据，就可以拿到需要的单元测试总用例数、失败用例数、告警数、执行时长等数据。这里同样参考上面提到的[fastlane的xcresult解析脚本](https://github.com/fastlane-community/trainer/blob/307d52bd6576ceefc40d3f57e34ce3653af10b6b/lib/trainer/test_parser.rb)。

为了简化上述逻辑，本项目提供了 [*unitTestInfo.rb*](./unitTestInfo.rb) 来直接提取需要的数据。

```shell
ruby unitTestInfo.rb --xcresult-path=path/to/xcresult_file --output-file=/path/to/output_file
```

例如执行：

```
╰─± ruby ../UnitTestParser/unitTestInfo.rb --xcresult-path=result.xcresult --output-file=result.txt
单元测试用例数：15
失败单元测试用例数：0
单元测试运行总时长：0.48s
```

同时这些数据也会被写入到 *result.txt* 文件中，便于其他工具读取。

```
╰─± cat result.txt
15
0
0.48
```
