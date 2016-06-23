## 介绍
这个示例项目是为了帮助使用AVOSCloud的开发者, 尽快的熟悉和使用SDK而建立的。主要展示AVOSCloud SDK的各种基础和高级用法.

## 如何运行

1. 用XCode打开AVOSDemo.xcodeproj，选择运行的scheme和设备，点击运行按钮或菜单`Product`->`Run`或快捷键`Command(⌘)`+`r`就可以运行此示例

2. 如果你想获取最新发布的SDK，你也可以使用`cocoapods`,将`Frameworks`目录下的文件删除，然后在终端执行代码:

	    pod install

    不出问题的话 1分钟即可完成所有设置, 并生成名为`AVOSDemo.xcworkspace`的Xcode工作空间，用Xcode打开它，按第1种介绍的方法运行即可

----

## 使用说明

### * 替换 App 信息

示例使用的是公共的 app id 和 app key，您可以在`AppDelegate.m`修改成您自己的应用 id 和 key。

### * 查看源码
您可以在Xcode中看到本项目的所有代码. 也可以在App运行和操作中更直观的查看.

1. 每一例子列表右上角都有`查看源码`的按钮, 可以直接查看本组例子的源码. 
2. 每一个例子运行界面也会直接显示当前列子的代码片段.  

![image](OtherSource/demorun.png)

### * 编译警告
代码中有一些人为添加的编译,是为了引起您足够的重视, 如果觉得没问题可以删除掉该行

### * 添加Demo

1. 新建一个继承`Demo`的类, 文件位置在项目的`AVOSDemo`文件夹
2. 在.m里的`@end`前加一句`MakeSourcePath` 用来在编译时生成返回这个文件的方法
3. 加一个demo方法. 方法必须以demo开头, 且必须是严格按照骆驼命名法, 否则方法名现实可能会有问题

----
## 其他

如果您在使用AVOSCloud SDK中, 有自己独特高效的用法, 非常欢迎您fork 并提交pull request, 帮助其他开发者更好的使用SDK. 我们将在本项目的贡献者中, 加入您的名字和联系方式(如果您同意的话)
