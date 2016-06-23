# KeepAlive

KeepAlive 是一个基于 AVOSCloud 实时通信 SDK 的 Demo 项目，其功能接近于聊天室。

---

### 如何运行

1. 用 Xcode 打开 KeepAlive.xcodeproj，选择运行的 scheme 和 设备，点击运行按钮或菜单`Product`->`Run`或快捷键`Command(⌘)`+`r`就可以运行此示例
2. 如果你想获取最新发布的SDK，你也可以使用`cocoapods`,将`Frameworks`目录下的文件删除，然后在终端执行代码:

	    pod install

    不出问题的话 1分钟即可完成所有设置, 并生成名为`KeepAlive.xcworkspace`的Xcode工作空间，用Xcode打开它，按第1种介绍的方法运行即可

---

### 使用说明

1. 示例使用的是公共的 app id 和 app key，您可以在 `AppDelegate.m` 修改成您自己的应用 id 和 key。
2. `KAViewController.m` 中有如下代码：

```
[_session open:@"selfId" withPeerIds:installationIds];
```
请将其中的 selfId 替换为你自己的 userId 或者 installationId。




