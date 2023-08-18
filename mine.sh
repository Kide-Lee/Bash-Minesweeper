#!/bin/bash
# Author: Kide_Lee
# Date: 2023.8.15
# Blog: https://www.cnblogs.com/-zyyz-/
 
# ========================================
# 用户设置
# 扫雷游戏中常见的难度设置：
# * 容易：9×9大小，10颗地雷；
# * 中等：16×16大小，40颗地雷；
# * 困难：30×16大小，99颗地雷。
# ========================================
width=9      # 界面的宽度
height=9     # 界面的高度
mineCount=10 # 地雷数量
mine="#"     # 地雷样式
title="MineSweeper"
 
# ========================================
# 方法
# 用一维数组模拟一张二维表；
# 下面提供若干方法，使脚本能够通过查询二维坐标的方式访问数组；
# 其中横纵坐标按书写方向，从零开始计数。
# ========================================
function ReadTable() {
    local x=$2
    local y=$3
 
    # matrix和field是脚本维护的两张表，
    # 其分别记录了雷区信息和用户界面。
    case "$1" in
    matrix) local info=("${matrix[@]}") ;;
    field) local info=("${field[@]}") ;;
    esac
 
    # 若读取的坐标越界或没有值，则返回0；否则返回坐标对应值。
    local result=${info[$(("$y" * "$width" + "$x"))]}
    if [ -z "$result" ]; then return 0;
    elif [ "$x" -lt 0 ]; then return 0;
    elif [ "$y" -lt 0 ]; then return 0;
    elif [ "$x" -ge $width  ]; then return 0;
    elif [ "$y" -ge $height ]; then return 0;
    else return "$result";
    fi
}
function WriteTable() {
    local x=$2
    local y=$3
    local new=$4
 
    # 若读取的坐标越界，则拒绝执行函数。
    if   [ "$x" -lt 0 ]; then return 0;
    elif [ "$y" -lt 0 ]; then return 0;
    elif [ "$x" -ge $width  ]; then return 0;
    elif [ "$y" -ge $height ]; then return 0;
    fi
 
    if [ "$1" == "matrix" ]; then
        matrix["$y" * "$width" + "$x"]=$new
    elif [ "$1" == "field" ]; then
        field["$y" * "$width" + "$x"]=$new
    fi
}
 
# ========================================
# 初始化
# matrix和field中储存的数字含义是一致的，
# 其中0-8代表这个格子周围的地雷数量；
# 9代表这个格子中埋藏了地雷；
# 10代表未检查过的格子；
# 11代表格子未检查，且被玩家标记，代表他认为这个格子下面有地雷；
# 12代表格子未检查，且被玩家标记，代表他不确定格子下面是否有地雷。
# ========================================
# 主函数
function StartGame() {
    # X和Y是模拟光标所在的坐标，即所谓的焦点；
    # 同时初始化old_x和old_Y，以供DrawFocus函数使用；
    # 并隐藏真实光标。
    X=$(("$width" / 2))
    Y=$(("$height" / 2))
    old_X=$X
    old_Y=$Y
    size=$(("$width" * "$height"))
    tput civis
    # 生成雷区
    # 此时还未开始布雷，所以雷区用0填充。
    for ((i = 0; i < "$size"; i++)); do
        matrix+=("0")
    done
    # 生成界面
    # 此时还未开始检查格子，所以用户界面用10填充。
    for ((i = 0; i < "$size"; i++)); do
        field+=("10")
    done
    DrawField
    # 等待用户翻开第一个格子，然后进行初始化。
    while [ -z "$checkFirst" ]; do
        DrawFocus $X $Y
        # IFS是定义分割符的环境变量，
        # 这里暂时将其设为空值，以确保read命令能够读到空格。
        IFS_back=$IFS
        IFS=
        read -srn1 input
        IFS=$IFS_back
        case "$input" in
        w|W) MoveUp ;;
        a|A) MoveLeft ;;
        s|S) MoveDown ;;
        d|D) MoveRight ;;
        f|F) MarkMatrix $X $Y 11 ;;     # 标记可能埋藏有地雷的格子。
        e|E) MarkMatrix $X $Y 12 ;;     # 标记不确定是否埋藏了地雷的格子。
        q|Q) return 1 ;;                # 退出游戏。
        " ")
            CreateMine
            CreateNumber
            CheckMatrix $X $Y           # 检查格子。
            local checkFirst="yes"
            startTime=$(date +%s)       # 准备就绪后开始计时。
            ;;
        esac
    done
}
# 绘制界面
function DrawField() {
    # 绘制标题栏
    tput clear
    local fieldWidth=$(("$width" * 3 + 2))
    local titleWidth=${#title}
    if [ "$fieldWidth" -gt "$titleWidth" ]; then
        tput cup 0 $(("$fieldWidth" / 2 - "$titleWidth" / 2))
        echo $title
    else
        tput cup 0 0
        echo $title
    fi
    # 绘制上边框
    echo -n +
    for ((i = 0; i < "$width"; i++)); do
        echo -n "---"
    done
    echo +
    # 绘制游戏区域
    for ((i = 0; i < "$height"; i++)); do
        echo -n "|"
        for ((j = 0; j < "$width"; j++)); do
            echo -n "[ ]"
        done
        echo "|"
    done
    # 绘制下边框
    echo -n +
    for ((i = 0; i < "$width"; i++)); do
        echo -n "---"
    done
    echo +
    # 增加游戏提示
    echo "move: WASD  check: Space"
    echo "mark: F  question: E  quit: Q"
}
# 铺设地雷
function CreateMine() {
    # 定义安全区，保证首次排雷安全
    local safeFieldList=()
    for x in $X-1 $X $X+1; do
        for y in $Y-1 $Y $Y+1; do
            x=$(("$x"))
            y=$(("$y"))
            local safeNum=$(("$y" * "$width" + "$x"))
            if [ $safeNum -ge 0 ] || [ $safeNum -lt "$size" ]; then
                safeFieldList+=("$safeNum")
            fi
        done
    done
    # 定义地雷，本质是一串互不重复的随机数
    local mineList=()
    while [ ${#mineList[*]} -lt $mineCount ]; do
        local random=$(("$RANDOM" % "$size"))
        local isRepeat=false
        for i in "${mineList[@]}" "${safeFieldList[@]}"; do
            if [ $random == "$i" ]; then
                isRepeat=true
                break
            fi
        done
 
        if [ $isRepeat == false ]; then
            mineList+=("$random")
        fi
    done
    # 布置地雷
    # 在雷区中，9代表有地雷
    for i in "${mineList[@]}"; do
        matrix["$i"]=9
    done
}
# 生成数字
function CreateNumber() {
    function PutOne() {
        local x=$1
        local y=$2
        for i in $x-1 $x $x+1; do
            for j in $y-1 $y $y+1; do
                local i=$(("$i"))
                local j=$(("$j"))
                ReadTable matrix $i $j
                tmpNum=$?
                if [ $tmpNum != 9 ]; then
                    WriteTable matrix $i $j $(("$tmpNum" + 1))
                fi
            done
        done
    }
    # 遇到地雷，非地雷邻格的数字+1。
    for ((y = 0; y < "$height"; y++)); do
        for ((x = 0; x < "$width"; x++)); do
            ReadTable matrix $x $y
            if [ $? == 9 ]; then
                PutOne $x $y
            fi
        done
    done
}
 
# ========================================
# 游戏过程
# ========================================
# 主函数
function PlayGame() {
    while true; do
        DrawFocus $X $Y
        # IFS是定义分割符的环境变量，
        # 这里暂时将其设为空值，以确保read命令能够读取到空格。
        IFS_back=$IFS
        IFS=
        read -srn1 input
        IFS=$IFS_back
        case "$input" in
        w|W) MoveUp ;;
        a|A) MoveLeft ;;
        s|S) MoveDown ;;
        d|D) MoveRight ;;
        f|F) MarkMatrix $X $Y 11 ;;     # 标记可能埋藏有地雷的格子。
        e|E) MarkMatrix $X $Y 12 ;;     # 标记不确定是否埋藏了地雷的格子。
        q|Q) return 1 ;;                # 退出游戏。
        " ")
            CheckMatrix $X $Y           # 检查格子
            if [ $? == 9 ]; then        # 检查到地雷后，终端响铃，游戏失败。
                tput bel
                return 2
            fi
            ;;
        esac
        Judging                         # 裁决是否赢得本场游戏
        if [ $? == 2 ]; then
            return 3
        fi
    done
}
# 检查雷区
function CheckCell() {
    local x=$1
    local y=$2
    ReadTable field "$x" "$y"
    local result=$?
    # 若格子未被检查，则进行检查,并绘制这个格子检查后的样子；
    if [ $result -ge 10 ]; then
        ReadTable matrix "$x" "$y"
        local result=$?
        WriteTable field "$x" "$y" "$result"
        Draw "$x" "$y"
    fi
    return "$result"
}
# 递归检查雷区
function CheckMatrix() {
    local x_1=$1
    local y_1=$2
    # 这个“edge”指空区的边缘
    # 边缘数组中边缘格的横纵坐标成对存储，
    # edgeLength是边缘数组的长度。
    local edgeList=("$x_1" "$y_1")
    local edgeLength=2
    while [ "$edgeLength" -gt 0 ]; do
        # 读取边缘坐标，并从边缘数组中删除掉它。
        local x=${edgeList[$edgeLength - 2]}
        local y=${edgeList[$edgeLength - 1]}
        unset "edgeList[$edgeLength-2]"
        unset "edgeList[$edgeLength-1]"
        # 检查边缘格，若边缘格四周无地雷，则将边缘格四周未检查的地方归为边缘格。
        CheckCell "$x" "$y"
        local result=$?
        if [ $result == 0 ]; then
            for i in $x-1 $x $x+1; do
                for j in $y-1 $y $y+1; do
                    local i=$(("$i"))
                    local j=$(("$j"))
                    ReadTable field $i $j
                    if [ $? -gt 9 ]; then
                        edgeList+=("$i" "$j")
                    fi
                done
            done
        fi
        # 读取边缘数组的长度，若边缘数组被抽空，则停止循环。
        local edgeLength=${#edgeList[@]}
    done
    # 将第一个格子的值作为返回值
    ReadTable field "$x_1" "$y_1"
    return $?
}
# 渲染
# 本函数同时仅能渲染一个格子。
function Draw() {
    local x=$1
    local y=$2
    # 读取field表，根据读到的值渲染格子。
    # 这里默认玩家终端所用的是等宽字体，并将一个格子设为三个字符的宽度。
    ReadTable field "$x" "$y"
    local result=$?
    case "$result" in
    0)  display="   " ;;                                    # 格子四周无雷，则不对其渲染；
    9)  display="$(tput setaf 1) ${mine} $(tput sgr0)" ;;   # 地雷标红，以示警告；
    10) display="[ ]" ;;                                    # 未检查过的格子用方括号括起来；
    11) display="$(tput setaf 2)[F]$(tput sgr0)" ;;         # 方括号内显示对格子的标记；
    12) display="$(tput setaf 3)[?]$(tput sgr0)" ;;         # 对于数字，对tput的颜色代码反序，以免和非数字格的颜色相重复。
    *)  display="$(tput setaf $((8 - "$result"))) ${result} $(tput sgr0)" ;;
    esac
    # 光标移到屏幕上的相应位置，并输出合适的内容。
    tput cup $(("$y" + 2)) $(("$x" * 3 + 1))
    echo -n "$(tput sgr0)${display}"
}
# 渲染焦点
# “焦点”就是游戏过程中的模拟光标。
function DrawFocus() {
    local x=$1
    local y=$2
    # 重新渲染旧焦点，来保证屏幕上只有一个焦点。
    Draw "$old_X" "$old_Y"
    # 对焦点反色，以突出焦点所在的位置。
    Draw "$x" "$y"
    tput cup $(("$y" + 2)) $(("$x" * 3 + 1))
    echo -n "$(tput rev)${display}"
    # 在下个焦点生成之前，定义好旧焦点。
    old_X=$1
    old_Y=$2
}
# 标记格子
function MarkMatrix() {
    local x=$1
    local y=$2
    local mark=$3
    ReadTable field "$x" "$y"
    local fieldChar=$?
    # 若将要打上的标记和旧标记一致，则取消标记；
    if [ $fieldChar == "$mark" ]; then
        WriteTable field "$x" "$y" 10
    # 对未检查过的格子进行标记。
    elif [ $fieldChar -gt 9 ]; then
        WriteTable field "$x" "$y" "$mark"
    fi
}
# 焦点的移动
# 当焦点越界时，让焦点进入界面的另一侧。
function MoveUp() {
    Y=$(("$Y" - 1))
    if [ $Y -lt 0 ]; then
        Y=$(("$Y" + "$height"))
    fi
}
function MoveDown() {
    Y=$(("$Y" + 1))
    if [ $Y -ge $height ]; then
        Y=$(("$Y" - "$height"))
    fi
}
function MoveLeft() {
    X=$(("$X" - 1))
    if [ $X -lt 0 ]; then
        X=$(("$X" + "$width"))
    fi
}
function MoveRight() {
    X=$(("$X" + 1))
    if [ $X -ge $width ]; then
        X=$(("$X" - "$width"))
    fi
}
# 裁判是否胜利
# 当场上所有未检查的格子均被标记，且它们的数量等于地雷数量时，判胜。
function Judging() {
    local markNum=0
    for i in "${field[@]}"; do
        if [ "$i" == 10 ] || [ "$i" == 12 ]; then
            return 1
        elif [ "$i" == 11 ]; then
            markNum=$(("$markNum"+1))
        fi
    done
    if [ "$markNum" == "$mineCount" ]; then
        return 2
    fi
}
 
# ========================================
# 游戏清算
# ========================================
function ClearGame() {
    # 结束计时。若游戏未曾初始化，则将时间计为0秒。
    endTime=$(date +%s)
    if [ "$startTime" ]; then
        time=$(("$endTime" - "$startTime"))
    else
        time=0
    fi
    # 清除焦点
    Draw $X $Y
    # 将标记正确的格子数量mineSweeper初始化为0。
    mineSweeper=0
    if [ $result == 1 ]; then    #若退出游戏
        for ((i = 0; i < ${#matrix[@]}; i++)); do
            x=$(("$i" % "$width"))
            y=$(("$i" / "$height"))
            if [ "${matrix[$i]}" == 9 ]; then
                # 将标记正确的格子染成绿色，并计数。
                if [ "${field[$i]}" == 11 ]; then
                    mineSweeper=$(("$mineSweeper" + 1))
                    Draw "$x" "$y"
                    tput cup $(("$y" + 2)) $(("$x" * 3 + 1))
                    echo -n "$(tput rev)$(tput setaf 2)[F]$(tput sgr0)"
                # 显示未找到的地雷
                else
                    Draw "$x" "$y"
                    tput cup $(("$y" + 2)) $(("$x" * 3 + 1))
                    echo -n "[${mine}]"
                fi
            fi
        done
        clearInfo="Game Exited.\nYou swept $mineSweeper mines in $time seconds."
    elif [ $result == 2 ]; then    # 若输掉游戏
        for ((i = 0; i < ${#matrix[@]}; i++)); do
            x=$(("$i" % "$width"))
            y=$(("$i" / "$height"))
            if [ "${matrix[$i]}" == 9 ]; then
                # 将标记正确的格子染成绿色，并去掉方括号以示地雷已爆炸，同时计数。
                if [ "${field[$i]}" == 11 ]; then
                    mineSweeper=$(("$mineSweeper" + 1))
                    Draw "$x" "$y"
                    tput cup $(("$y" + 2)) $(("$x" * 3 + 1))
                    echo -n "$(tput rev)$(tput setaf 2) ${mine} $(tput sgr0)"
                # 将标记错误或未标记的格子染成红色，并去掉方括号以示地雷爆炸
                else
                    Draw "$x" "$y"
                    tput cup $(("$y" + 2)) $(("$x" * 3 + 1))
                    echo -n "$(tput rev)$(tput setaf 1) ${mine} $(tput sgr0)"
                fi
            fi
        done
        clearInfo="$(tput setaf 1)The Game Failed. \nYou swept $mineSweeper mines in $time seconds."
    elif [ $result == 3 ]; then    # 若赢得游戏
        clearInfo="$(tput setaf 2)You Win!\nYou swept all mines in $time seconds."
    fi
    # 输出结语,并恢复光标。
    tput cnorm
    tput cup $(("$height" + 3)) 0
    tput el
    echo -e "$(tput rev)${clearInfo}$(tput sgr0)"
}
 
# ========================================
# 游戏运行
# 游戏初始化成功后再进行游戏。
# ========================================
StartGame
result=$?
if [ $result == 0 ]; then
    PlayGame
    result=$?
fi
ClearGame