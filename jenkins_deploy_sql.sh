#!/usr/bin/env bash
#
# * @file            jenkins_deploy_sql.sh
# * @description     自动备份数据库并执行 SQL 文件
# * @author          ygqygq2 <ygqygq2@qq.com>
# * @createTime      2024-06-22 17:37:23
# * @lastModified    2024-06-22 17:58:28
# * Copyright ©ygqygq2 All rights reserved
#

#获取脚本所存放目录
cd $(dirname $0)
bash_path=$(pwd)

#脚本名
me=$(basename $0)
backup_dir="$bash_path/backup/$(date +%F-%s)"
# delete dir and keep days
delete_dirs=("$bash_path/backup:15")
log_dir="$backup_dir/log"
shell_log="$log_dir/$(basename ${me}).log"
# 从JekinsFile定义的环境变量中获取用户名和密码信息.
MYSQL_USER=$MYSQL_OPR_USR
MYSQL_PASSWORD=$MYSQL_OPR_PSW
# 在Jekinsfile文件中定义环境变量MYSQL_PROG
[ ! -f "${MYSQL_PROG}" ] && MYSQL_PROG=mysql
MYSQL_DUMP="${MYSQL_PROG}dump"

#定义保存日志函数
function save_log() {
    echo -e "$(date +%F\ %T) $*" >>$shell_log
}

[ ! -d $log_dir ] && mkdir -p $log_dir

#定义输出颜色函数
function red_echo() {
    #用法:  red_echo "内容"
    local what="$*"
    echo -e "$(date +%F-%T) \e[1;31m ${what} \e[0m"
}

function green_echo() {
    #用法:  green_echo "内容"
    local what="$*"
    echo -e "$(date +%F-%T) \e[1;32m ${what} \e[0m"
}

function yellow_echo() {
    #用法:  yellow_echo "内容"
    local what="$*"
    echo -e "$(date +%F-%T) \e[1;33m ${what} \e[0m"
}

function blue_echo() {
    #用法:  blue_echo "内容"
    local what="$*"
    echo -e "$(date +%F-%T) \e[1;34m ${what} \e[0m"
}

function twinkle_echo() {
    #用法:  twinkle_echo $(red_echo "内容")  ,此处例子为红色闪烁输出
    local twinkle='\e[05m'
    local what="${twinkle} $*"
    echo -e "$(date +%F-%T) ${what}"
}

function return_echo() {
    if [ $? -eq 0 ]; then
        echo -n "$* " && green_echo "成功"
        return 0
    else
        echo -n "$* " && red_echo "失败"
        return 1
    fi
}

function return_error_exit() {
    [ $? -eq 0 ] && local REVAL="0"
    local what=$*
    if [ "$REVAL" = "0" ]; then
        [ ! -z "$what" ] && { echo -n "$* " && green_echo "成功"; }
    else
        red_echo "$* 失败，脚本退出"
        exit 1
    fi
}

# 定义确认函数
function user_verify_function() {
    while true; do
        echo ""
        read -p "是否确认?[Y/N]:" Y
        case $Y in
        [yY] | [yY][eE][sS])
            echo -e "answer:  \\033[20G [ \e[1;32m是\e[0m ] \033[0m"
            break
            ;;
        [nN] | [nN][oO])
            echo -e "answer:  \\033[20G [ \e[1;32m否\e[0m ] \033[0m"
            exit 1
            ;;
        *)
            continue
            ;;
        esac
    done
}

# 定义跳过函数
function user_pass_function() {
    while true; do
        echo ""
        read -p "是否确认?[Y/N]:" Y
        case $Y in
        [yY] | [yY][eE][sS])
            echo -e "answer:  \\033[20G [ \e[1;32m是\e[0m ] \033[0m"
            break
            ;;
        [nN] | [nN][oO])
            echo -e "answer:  \\033[20G [ \e[1;32m否\e[0m ] \033[0m"
            return 1
            ;;
        *)
            continue
            ;;
        esac
    done
}

function backup_db() {
    local db=$1
    echo "####################### 备份[$db]开始 ##########################"
    echo $MYSQL_DUMP --host $MYSQL_HOST --port $MYSQL_PORT --user=$MYSQL_USER --password=$MYSQL_PASSWORD \
        --set-gtid-purged=OFF --no-create-db --triggers --routines --events \
        --single-transaction --databases $db >$backup_dir/${db}.dump
    save_log "备份[$db]"
    $MYSQL_DUMP --host $MYSQL_HOST --port $MYSQL_PORT --user=$MYSQL_USER --password=$MYSQL_PASSWORD \
        --set-gtid-purged=OFF --no-create-db --triggers --routines --events \
        --single-transaction --databases $db >$backup_dir/${db}.dump
    return_echo "备份数据库[$db]"
}

function check_db() {
    local db=$1
    $MYSQL_PROG --host $MYSQL_HOST --port $MYSQL_PORT --user=$MYSQL_USER --password=$MYSQL_PASSWORD \
        -N -e 'show databases;' | egrep "^${db}$"
    return_echo "查询 db [$db] 存在"
}

function deploy_db() {
    # 初始退出码
    exit_code=0
    yellow_echo "# 执行SQL列表 #"
    ls -lR $SQL_DIR
    cd $SQL_DIR
    for db_dir in $(ls | sort -d); do
        # 处理db名字是 01-库名格式，库名不能有 - 号
        db_pre=$(echo $db_dir | awk '/^[0-9]./')
        if [ -n $db_pre ]; then
            #echo $db_dir
            db=${db_dir##*-}
        else
            db=$db_dir
        fi
        # 查询是否存在数据库
        check_db $db
        # 检测失败则跳过
        [ $? -ne 0 ] && red_echo "# 请检查数据库 [$db] 是否存在或者目录是否正确 !!!" &&
            exit_code=$(($exit_code + 1)) && continue
        backup_db $db
        [ $? -ne 0 ] && red_echo "# 请检查数据库 [$db] 备份情况 !!!" &&
            exit_code=$(($exit_code + 1)) && continue
        for sql in $(find $db_dir -name *.sql -type f | sort -n); do
            echo "####################### 导入 [$db] < $sql ##########################"
            echo ${MYSQL_PROG} -v -v -v --host $MYSQL_HOST --port $MYSQL_PORT \
                --user=$MYSQL_USER --password=$MYSQL_PASSWORD --connect-timeout 10 $db <$sql
            save_log "导入[$db] < $sql"
            ${MYSQL_PROG} -v -v -v --host $MYSQL_HOST --port $MYSQL_PORT \
                --user=$MYSQL_USER --password=$MYSQL_PASSWORD --connect-timeout 10 $db <$sql
            [ $? -ne 0 ] && red_echo "# 数据库 [$db] 导入 [$sql] 出错 !!!" &&
                exit_code=$(($exit_code + 1)) && break
        done
    done
}

function delete_old_files() {
    for delete_dir_keep_days in ${delete_dirs[@]}; do
        delete_dir=$(echo $delete_dir_keep_days | awk -F':' '{print $1}')
        keep_days=$(echo $delete_dir_keep_days | awk -F':' '{print $2}')
        [ -n "$delete_dir" ] && cd ${delete_dir}
        [ $? -eq 0 ] && find -L ${delete_dir} -mindepth 1 -mtime +$keep_days -prune -exec rm -rf {} \;
        cd $bash_path
    done
}

deploy_db
delete_old_files

echo "###### 退出码(失败次数) $exit_code ######"
exit $exit_code
