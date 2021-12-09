# UnitTestParser

单元测试数据解析脚本&工具，快速解析单元测试执行概况及各种维度的代码覆盖率。

> [UnitTestDemo](https://github.com/JerryChu/UnitTestDemo) 项目是单元测试及覆盖率统计的Demo工程，可以使用该工程进行本项目提供的脚本的学习和使用。

## 特性

- 解析单元测试执行概况
- 解析代码覆盖率
- 解析增量代码覆盖率
- 解析个人代码覆盖率

## 单元测试执行概况

获取单元测试方法个数、执行失败个数、执行时长等。

```shell
ruby unitTestInfo.rb --xcresult-path=path/to/xcresult_file --output-file=/path/to/output_file
```

参考 [单元测试结果数据解析文档](./docs/unitTestInfo.md)

## 单元测试执行日志

单元测试执行完毕后，xcresult文件会删除执行过程日志，需要通过解析xcresult文件获取日志路径，进而提取日志。

```shell
ruby unitTestLog.rb --xcresult-path=../UnitTestDemo/test.xcresult --output-path=./UnitTestLog
```

## 代码覆盖率

获取整体覆盖率以及各个target的代码覆盖率数据。

```shell
ruby targetCoverage.rb --cov-json-path=path/to/json_file --output-file=path/to/output_file
```

参考 [代码覆盖率解析文档](./docs/targetCoverage.md)

## 增量代码覆盖率

### 获取增量代码

使用`git diff`命令可以获取到增量代码，但是`git diff`是没法直接使用的，我们需要对diff结果进行解析，获取到新增的所有文件及代码行。

参考 [diff数据解析文档](./docs/diffParser.md)

### 统计增量代码覆盖率

获取增量代码覆盖率数据。

```
ruby deltaCoverage.rb --xcresult-path=path/to/xcresult_file --proj-dir=./ --diff-file=path/to/diff_file --output-file=deltaCov.txt
```

参考 [增量覆盖率数据解析文档](./docs/deltaCoverage.md)

## 个人代码覆盖率

获取个人代码覆盖率数据和个人增量代码覆盖率数据。

```
# 个人代码覆盖率
ruby userCoverage.rb --xcresult-path=path/to/xcresult_file --proj-dir=./ --output-file=userCov.html
# 个人增量代码覆盖率
ruby userCoverage.rb --xcresult-path=path/to/xcresult_file --proj-dir=./ --output-file=userCov.html --begin-date=2020-08-08
```

参考 [个人覆盖率数据解析文档](./docs/userCoverage.md)
