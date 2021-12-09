# 代码覆盖率统计

>  建议先阅读[单元测试结果数据解析文档](./unitTestInfo.md)。

统计整体代码覆盖率以及各个target的代码覆盖率数据。


## 解析代码覆盖率文件

使用苹果官方提供的命令行工具`xccov`即可完成代码覆盖率的解析，并且可以获取到整体的代码覆盖率及各个模块的代码覆盖率。

```
xcrun xccov view --report --json #{xcresult_path} > #{json_path}
```

拿到json文件后，就可以通过解析json文件来获取代码覆盖率。  
本项目提供 [*target.rb*](../targetCoverage.rb) 来解析整体代码覆盖率和分模块的代码覆盖率。

```
# 传入文件为使用`xccov`解析之后的json文件
ruby targetCoverage.rb --cov-json-path=path/to/json_file --output-file=path/to/output_file
```

例如执行：

```
╰─± ruby targetCoverage.rb --cov-json-path=result.json --output-file=result.html
```

我们就可以得到如下的结果：

```text
target	        可执行代码行数 覆盖代码行数  代码覆盖率
All                 424         313       73.8%
DemoTests.xctest    223         217       97.3%
Demo.app            201         96        47.7%
```
