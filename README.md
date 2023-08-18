> A simple command-line game by bash, that can be run in Linux.</br>
> 一款用bash写的命令行小游戏，可以在Linux系统中运行。

## 前言
不知道为什么，这个脚本和CentOS 7不兼容。

由于这个**扫雷**小游戏最初是作为博文发表的，因此在脚本源代码中，我加入了自认为非常详尽的注释。列位想要了解脚本运行逻辑或自定义想要的功能的话，欢迎直接阅读我写的[源代码](https://github.com/Kide-Lee/Bash-Minesweeper/blob/main/mine.sh)。

本项目首发于：https://www.cnblogs.com/-zyyz-/p/17635907.html

## 怎么玩
载入脚本后，用WASD键控制光标移动，按空格挖开地块，挖到的数字是地块周围的地雷数量，挖到地雷后游戏失败；

按F标记有地雷的地块，按E表示可能有地雷。已挖开的地块无法被标记。将所有地雷标记完毕后游戏胜利。

按Q键退出游戏。无论如何退出游戏，脚本都会总结扫到雷的数量和本局游戏的时间。