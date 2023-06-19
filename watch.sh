#!/bin/bash
#--------------------------------------------
# 🚀 Hyperf Watch Scripts
# 😊 Make Coding More Happy
# 👉 监听文件变化自动重启Hyperf
# Author: 左星辰
# Version: 3.0.0
#--------------------------------------------

# 监听目录
WATCH_DIR="./"
# 监听扩展名（多个用/分隔）
WATCH_EXT="php/env"
# 运行命令
RUN_CMD="php ./bin/hyperf.php start"
# 日志路径
WATCH_LOG="./runtime/watch.log"
# fswatch路径
FS_WATCH="fswatch"
COLOR_RESET='\033[0m' # 重置所有属性
COLOR_START='\033[1;32m' # 绿色，用于启动信息
COLOR_RESTART='\033[1;33m' # 黄色，用于重启信息
COLOR_MODIFIED='\033[1;34m' # 蓝色，用于文件修改信息
# 排除文件扩展名/文件夹(正则表达式)
EXCLUDE_REGX="\.json|\.lock|.idea|.git|vendor|runtime|test|config|.github"

# 帮助指南
if [[ $1 = "-h" || $1 = "help" ]];then
    echo -e "📚 Hyperf Watch Scripts 帮助指南"
    echo -e "Usage:  watch [path] [-] [options] [args]"
    echo -e "\twatch : 默认监听目录路径为{${WATCH_DIR}}不清除监听日志"
    echo -e "\twatch -c : 默认监听目录路径为{${WATCH_DIR}}并清除监听日志"
    echo -e "\twatch -e xxx : 默认监听目录路径为{${WATCH_DIR}}并设置监听扩展名xxx"
    echo -e "\twatch -g xxx : 默认监听更改文件某几行详情"
    echo -e "\twatch -h : 查看帮助指南"
    echo -e "\twatch help: 查看帮助指南"
    echo -e "\twatch ./app : 设置监听目录路径为{./app}"
    echo -e "\twatch ./app -c : 设置监听目录路径为{./app}并清除监听日志"
    echo -e "\twatch ./app -e xxx -c: 设置监听目录路径为{./app}并设置监听扩展名xxx并清除监听日志"
    exit 1
fi

# 检查fswatch是否安装
command -v ${FS_WATCH} >/dev/null 2>&1 || { echo >&2 "[x] 请先安装fswatch"; exit 1;}

# 是否设置监听目录
if [[ $1 != "" && $1 != "-c" && $1 != "-e" && $1 != "-r" ]];then
    WATCH_DIR=$1
    if [[ ! -d ${WATCH_DIR} ]];then
        echo "[x] 请确认目录{$WATCH_DIR}存在且拥有访问权限"
        exit 1
    fi
fi

# 是否设置监听扩展名
if [[ $* =~ "-e" ]];then
    ARGS=${*##*-c}
    ARGS=${ARGS#*-e}
    WATCH_EXT=${ARGS// /}
    if [[ ${WATCH_EXT} = "" ]]; then
        echo "[x] 请设置监听扩展名，多个用/分隔"
        exit 1
    fi
fi

echo -e "🐵 加载 Hyperf Watch 脚本"
echo -e "👉 Watching Dir @ {${WATCH_DIR}}"
echo -e "👉 Watching File Extension @ {${WATCH_EXT}}"
echo -e "👉 Watching Log File @ {${WATCH_LOG}}"
echo -e "👉 Running Command {${RUN_CMD}}"

# 是否需要清理监听日志
if [[ $* =~ "-c" ]];then
    # 判断目录是否存在
    if [[ ! -d ${WATCH_LOG%/*} ]];then
        mkdir ${WATCH_LOG%/*}
    fi
    if [[ -f ${WATCH_LOG} ]];then
        rm -rf ${WATCH_LOG}
    fi
    echo -e "👉 Clean Watch Log Success"
fi

isGit="false"
#如果输入了-g参数，判断是否在git仓库中
if [[ $* =~ "-g" ]];then
   if  git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
      isGit="true"
   fi
fi

# 结束已启动的进程
PID=$(ps -ef | grep "${RUN_CMD}" | grep -v grep | awk '{print $2}')
if [[ ${PID} != "" ]];then
    kill -9 ${PID}
fi

START="🚀 Start @ $(date "+%Y-%m-%d %H:%M:%S")"
echo -e "\n ================================ \n ${START}\n ================================ \n" >> ${WATCH_LOG}

# 后台运行并将输出保存到监听日志路径
nohup ${RUN_CMD} >> ${WATCH_LOG} 2>&1 &
#将日志输出到控制台
tail -f ${WATCH_LOG} &

# 开始监听
${FS_WATCH} -Ee ${EXCLUDE_REGX} --event IsFile ${WATCH_DIR} | while read file
do
    # 如果匹配监听扩展名
    if [[ ${WATCH_EXT} =~ ${file##*.} ]];then
        # 获取文件变更内容和行号
        if [[ ${isGit} = "true" ]];then
            diff_output=$(git diff HEAD --unified=0 --no-color "${file}")
            diff_lines=$(echo -e "${COLOR_MODIFIED}${diff_output}" | grep "^@@ " | sed -r "s/@@ .+?\+(.+?),.+\@\@/\1/")
        fi
        # 重启进程
        ps -ef | grep "${RUN_CMD}" | grep -v grep | awk '{print $2}' | xargs kill
        RESTART="🔄 Restart @ $(date "+%Y-%m-%d %H:%M:%S")"
        echo -e "\n ================================ \n ${RESTART}\n 👉 $file was modified.\n\n${diff_output}\n\nAffected lines: ${diff_lines}\n=============================== \n" >> ${WATCH_LOG}
        nohup ${RUN_CMD} >> ${WATCH_LOG} 2>&1 &
        echo ${RESTART}
    fi
done

# 退出杀全部启动进程
ps -ef | grep "${RUN_CMD}" | grep -v grep | awk '{print $2}' | xargs kill
# 挂载监听日志
cat ${WATCH_LOG}
rm -rf ${WATCH_LOG}
