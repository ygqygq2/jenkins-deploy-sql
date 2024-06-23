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
DB_USER=$DB_OPR_USR
DB_PASSWORD=$DB_OPR_PSW
# 在Jekinsfile文件中定义环境变量MYSQL_PROG
[ ! -f "${DB_PROG}" ] && DB_PROG=mysql
DB_DUMP="${DB_PROG}dump"

. $bash_path/functions/base.sh
. $bash_path/functions/mysql.sh

# 动态选择并调用相应的数据库操作函数
function Call_Db_Function() {
  local operation=$1
  local db_type=$DB_TYPE
  local function_name="${operation}_${db_type}" # 构造函数名称

  if declare -f "$function_name" >/dev/null; then
    # 如果函数存在，调用之
    $function_name
  else
    echo "不支持的数据库类型或操作: $function_name"
    return 1
  fi
}

function Delete_Old_Files() {
  for delete_dir_keep_days in ${delete_dirs[@]}; do
    delete_dir=$(echo $delete_dir_keep_days | awk -F':' '{print $1}')
    keep_days=$(echo $delete_dir_keep_days | awk -F':' '{print $2}')
    [ -n "$delete_dir" ] && cd ${delete_dir}
    [ $? -eq 0 ] && find -L ${delete_dir} -mindepth 1 -mtime +$keep_days -prune -exec rm -rf {} \;
    cd $bash_path
  done
}

Call_Db_Function "Deploy_Db"
Delete_Old_Files

echo "###### 退出码(失败次数) $exit_code ######"
exit $exit_code
