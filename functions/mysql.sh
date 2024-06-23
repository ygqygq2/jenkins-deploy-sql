function Backup_Db_Mysql() {
  local db=$1
  echo "####################### 备份[$db]开始 ##########################"
  Save_Log "备份[$db]"
  $MYSQL_DUMP --host $MYSQL_HOST --port $MYSQL_PORT --user=$MYSQL_USER --password=$MYSQL_PASSWORD \
    --set-gtid-purged=OFF --no-create-db --triggers --routines --events \
    --single-transaction --databases $db >$backup_dir/${db}.dump
  Return_Echo "备份数据库[$db]"
}

function Check_Db_Mysql() {
  local db=$1
  $MYSQL_PROG --host $MYSQL_HOST --port $MYSQL_PORT --user=$MYSQL_USER --password=$MYSQL_PASSWORD \
    -N -e 'show databases;' | egrep "^${db}$"
  Return_Echo "查询 db [$db] 存在"
}

function Deploy_Db_Mysql() {
  # 初始退出码
  exit_code=0
  Yellow_Echo "# 执行SQL列表 #"
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
    Check_Db_Mysql $db
    # 检测失败则跳过
    [ $? -ne 0 ] && Red_Echo "# 请检查数据库 [$db] 是否存在或者目录是否正确 !!!" &&
      exit_code=$(($exit_code + 1)) && continue
    Backup_Db_Mysql $db
    [ $? -ne 0 ] && Red_Echo "# 请检查数据库 [$db] 备份情况 !!!" &&
      exit_code=$(($exit_code + 1)) && continue
    for sql in $(find $db_dir -name *.sql -type f | sort -n); do
      echo "####################### 导入 [$db] < $sql ##########################"
      echo ${MYSQL_PROG} -v -v -v --host $MYSQL_HOST --port $MYSQL_PORT \
        --user=$MYSQL_USER --password=$MYSQL_PASSWORD --connect-timeout 10 $db <$sql
      Save_Log "导入[$db] < $sql"
      ${MYSQL_PROG} -v -v -v --host $MYSQL_HOST --port $MYSQL_PORT \
        --user=$MYSQL_USER --password=$MYSQL_PASSWORD --connect-timeout 10 $db <$sql
      [ $? -ne 0 ] && Red_Echo "# 数据库 [$db] 导入 [$sql] 出错 !!!" &&
        exit_code=$(($exit_code + 1)) && break
    done
  done
}
