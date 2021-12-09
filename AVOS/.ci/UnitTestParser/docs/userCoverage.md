# 个人代码覆盖率统计

>  建议先阅读[单元测试结果数据解析文档](./unitTestInfo.md) 和 [代码覆盖率统计文档](./targetCoverage.md)。

## 简介

有时候我们想要知道项目中每个成员提交的代码覆盖率数据，辅助我们去评估大家提交的代码质量如何，同时也激励大家写出更高质量的单元测试。  

那么如何统计项目中所有代码提交者（committer）的代码覆盖率情况呢？首先我们得知道每一个committer到底提交了那些代码（精确到代码行），然后在此基础上确认这些代码行是否覆盖，最后计算得到代码覆盖率。

### 代码行负责人

我们知道在Xcode中点击代码编辑器右上角的 *Author* 按钮，就能够看到当前文件每一行代码的“负责人”，也就是谁最后增新增或者修改了这一行。这个功能是怎么实现的呢？其实就是基于`git blame`命令。

> git-blame - Show what revision and author last modified each line of a file

（详细用法可以在命令行中输入`git blame`查看，或者参考[官方文档](https://git-scm.com/docs/git-blame)。）

比如在[Demo项目](https://github.com/JerryChu/UnitTestDemo)目录下命令行中执行：

```objc
╰─± git blame -c --date=short Demo/CDataUtil.h
```

就能看到如下输出：

```text
9caa7b6b        (  jerrychu     2020-03-29      1)//
9caa7b6b        (  jerrychu     2020-03-29      2)//  CDataUtil.h
9caa7b6b        (  jerrychu     2020-03-29      3)//  Demo
9caa7b6b        (  jerrychu     2020-03-29      4)//
9caa7b6b        (  jerrychu     2020-03-29      5)//  Created by JerryChu on 2019/12/15.
9caa7b6b        (  jerrychu     2020-03-29      6)//  Copyright © 2019 Chu. All rights reserved.
9caa7b6b        (  jerrychu     2020-03-29      7)//
9caa7b6b        (  jerrychu     2020-03-29      8)
9caa7b6b        (  jerrychu     2020-03-29      9)#import <Foundation/Foundation.h>
9caa7b6b        (  jerrychu     2020-03-29      10)
9caa7b6b        (  jerrychu     2020-03-29      11)NS_ASSUME_NONNULL_BEGIN
9caa7b6b        (  jerrychu     2020-03-29      12)
9caa7b6b        (  jerrychu     2020-03-29      13)@interface CDataUtil : NSObject
9caa7b6b        (  jerrychu     2020-03-29      14)
9caa7b6b        (  jerrychu     2020-03-29      15)/// 将数字转化为字符串
9caa7b6b        (  jerrychu     2020-03-29      16)/// @discussion 大于等于10万时，展示xx万，不带小数点
9caa7b6b        (  jerrychu     2020-03-29      17)/// @discussion 大于等于1万时，展示1.x万，保留一位小数点
9caa7b6b        (  jerrychu     2020-03-29      18)/// @discussion 低于1万时，展示实际数字
9caa7b6b        (  jerrychu     2020-03-29      19)/// @param count 数字
9caa7b6b        (  jerrychu     2020-03-29      20)+ (NSString *)descForCount:(NSInteger)count;
9caa7b6b        (  jerrychu     2020-03-29      21)
9caa7b6b        (  jerrychu     2020-03-29      22)/// 将数字转化为字符串
9caa7b6b        (  jerrychu     2020-03-29      23)/// @discussion 大于等于10万时，展示xx万，不带小数点
9caa7b6b        (  jerrychu     2020-03-29      24)/// @discussion 大于等于1万时，展示1.x万，保留一位小数点
9caa7b6b        (  jerrychu     2020-03-29      25)/// @discussion 大于`countThreshold`时，展示实际数字
9caa7b6b        (  jerrychu     2020-03-29      26)/// @discussion 小于等于`countThreshold`时，不展示
9caa7b6b        (  jerrychu     2020-03-29      27)/// @param count 数字
9caa7b6b        (  jerrychu     2020-03-29      28)+ (NSString *)descForCount2:(NSInteger)count;
9caa7b6b        (  jerrychu     2020-03-29      29)
7e08d03f        (jerrychu(褚佳义)       2020-05-01      30)// 将threshold作为参数传入，避免内部产生依赖
7e08d03f        (jerrychu(褚佳义)       2020-05-01      31)+ (NSString *)descForCount2:(NSInteger)count withThreshold:(NSInteger)threshold;
7e08d03f        (jerrychu(褚佳义)       2020-05-01      32)
9caa7b6b        (  jerrychu     2020-03-29      33)@end
9caa7b6b        (  jerrychu     2020-03-29      34)
9caa7b6b        (  jerrychu     2020-03-29      35)NS_ASSUME_NONNULL_END
```

既然通过`git blame`命令就能找到项目中的每一行的代码负责人，那接下来的具体步骤就很清晰了。   

### 具体步骤

1. 遍历所有文件，获取每个committer负责所有代码行。
2. 遍历其负责的代码行数据，确定代码行是否被覆盖。
3. 对每个committer分别统计代码覆盖率。

第一步通过对`git blame`命令的输出结果进行解析和统计，就可以得到。  
第二步可以直接参考之前的[增量代码覆盖率统计](./deltaCoverage.md)文章，里面详细得介绍了如何判断代码行是否被覆盖，原理是一样的。  
第三步就是单纯的计算了，没啥可说的，写出来主要是为了分三步走。  

### 脚本实现

本项目提供了 [*userCoverage.rb*](https://github.com/JerryChu/UnitTestParser/blob/master/userCoverage.rb) 脚本来实现个人代码覆盖率的解析和输出。

例如执行：

```
╰─± ruby ../UnitTestParser/userCov.rb --xcresult-path=test.xcresult --output-file=userCov.html --proj-dir=./
```

则会生成如下的html

```html
代码覆盖率（from 1970-01-01 to 2020-08-09）
开发者	增加/修改代码行数	覆盖代码行数	覆盖率
jerrychu	154	            130 	0.84
```

### 注意事项

1. 脚本中使用的 *test.xcresult* 文件为我本地生成的结果文件，大家使用Demo项目测试该命令之前，需要先在自己机器上重新生成一份 *test.xcresult* 文件，否则会由于路径不匹配导致无法获取结果数据。  

    如何生成 *test.xcresult* 文件呢？之前的文章都已经提到过，这里再复习一遍。

    ```shell
    # for xcodeproj
    xcodebuild test -project Demo.xcodeproj -scheme Demo -derivedDataPath "${BUILD_DIR}/" -destination "${SIMULATOR_PLATFORM}" -resultBundlePath "${XCRESULT_PATH}" -resultBundleVersion 3
    ```

2. 脚本中需要设置开发人员名单，不在名单内的数据将不会被统计进去。

    ```ruby

    # 要统计的开发者列表
    $developer_list = ["jerrychu"]
    ```

## 个人新增代码覆盖率

如果详细看了 *userCov.rb* 脚本的话，大家会发现脚本执行参数中有一个 *begin_date* 选项，用于指定从什么时间点开始统计。

为什么要加这样一个参数呢？我们在统计每个committer的代码覆盖率时，更希望看到最近一段时间（比如当前版本的开始时间）内每个committer提交的代码的覆盖率情况。而`git blame`会把项目中每一个代码行都展示出来，但是其中很多是历史代码，参考意义不大。

附：`git blame` 也提供一些参数用来设置时间区间或commit区间，但是并不符合我们这里的统计需求，有兴趣的可以在命令行中执行`git help blame`看下。

设置 *begin_date* 选项之后，脚本里在解析`git blame`结果时，就会将这个时间点之前的代码行都过滤掉，只统计这个时间点之后新增或修改的代码行。在实际应用中，我们可以把这个参数设置为版本开始的时间，用来统计从版本开始到现在，大家提交代码的覆盖率情况。

```ruby
# 根据git blame统计begin_date时间之后每个人修改过的文件及行数
def user_files_map(proj_dir, begin_date)
```

在执行脚本时增加 *begin-date* 参数即可统计到该时间点之后的committer新增代码覆盖率情况。

```
╰─± ruby ../UnitTestParser/userCov.rb --xcresult-path=test.xcresult --proj-dir=./ --output-file=userCov.html --begin-date="2020-08-08"
```

## 总结

个人代码覆盖率的统计对提升每个项目成员的单元测试水平和整体单元测试水平都有重要的作用。  
[UnitTestParser](https://github.com/JerryChu/UnitTestParser)项目提供的脚本可以快速准确地解析出项目中每个人的代码覆盖率，以及每个人的增量代码覆盖率，并且可以做到自动化统计。