function Backup_Db_Surreal() {
  local db=$1
  echo "####################### 备份[$db]开始 ##########################"
  Save_Log "备份[$db]"
  $SURREAL_PROG export --conn ws://$SURREAL_HOST:$SURREAL_PORT --user $SURREAL_USER --pass $SURREAL_PASSWORD \
    --ns $SURREAL_NAMESPACE --db $db $backup_dir/${db}.export.surql
  Return_Echo "备份数据库[$db]"
}

function Check_Db_Surreal() {
  # 暂时还没有查询方法
  local db=$1
  $SURREAL_PROG --conn ws://$SURREAL_HOST:$SURREAL_PORT --user $SURREAL_USER --pass $SURREAL_PASSWORD \
    --ns $SURREAL_NAMESPACE 'show databases' | egrep "^${db}$"
  Return_Echo "查询 db [$db] 存在"
}

function Deploy_Db_Surreal() {
  # 初始退出码
  exit_code=0
  Yellow_Echo "# 执行SQL列表 #"
  ls -lR $SQL_DIR
  cd $SQL_DIR
  # validate
  ${SURREAL_PROG} validate **/*.surql

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
    # Check_Db_SURREAL $db
    # 检测失败则跳过
    # [ $? -ne 0 ] && Red_Echo "# 请检查数据库 [$db] 是否存在或者目录是否正确 !!!" &&
    #   exit_code=$(($exit_code + 1)) && continue

    Backup_Db_Surreal $db
    [ $? -ne 0 ] && Red_Echo "# 请检查数据库 [$db] 备份情况 !!!" &&
      exit_code=$(($exit_code + 1)) && continue
    for sql in $(find $db_dir -name *.surql -type f | sort -n); do
      echo "####################### 导入 [$db] < $sql ##########################"
      Save_Log "导入[$d] < $sql"
      ${SURREAL_PROG} import --conn ws://$SURREAL_HOST:$SURREAL_PORT \
        --user $SURREAL_USER --pass $SURREAL_PASSWORD --ns $SURREAL_NAMESPACE --db $db $sql
      [ $? -ne 0 ] && Red_Echo "# 数据库 [$db] 导入 [$sql] 出错 !!!" &&
        exit_code=$(($exit_code + 1)) && break
    done
  done
}
