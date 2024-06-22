# 1. 说明

此仓库为 SQL 批量发版 Jenkinsfile 和脚本。

## 1.1 `Jenkinsfile`

`Jenkinsfile`为批量部署的 Jenkins 所使用的 Jenkinsfile。其内调用的是下文 2 中的批量更新脚本。

新建一个 pipeline 流水线`ops-update-pre-sql`，使用此 git 的`Jenkinsfile`，jenkins 不需要配置参数。

## 1.2 JenkinsFile 文件配置环境变量
按实际情况修改

# 2. 批量更新脚本

`Jenkinsfile` 中直接调用脚本，使用 Jenkins 传入的环境变量。

# 3. Jenkins 设置

Jenkins 中添加凭证，使用 "Username with password"，

# 4. SQL 发版方法

## 4.1 发版的 sql 文件压缩包目录结构
* 按库名为压缩包的子目录，如果子目录需要排序，则按子目录名字是 `01-库名格式`，库名不能有 - 号；
* 库名目录下可以有更多层子目录，如果子目录下的 sql 文件有导入顺序，同目录下 sql 文件名前面最好加上数字，让其排序。

## 4.2 执行`jekins`任务自动批量跑 sql 文件

## 4.3 SQL 执行出错处理

- 脚本逻辑

1. 根据 SQL 目录的子目录获取库名；
2. 在数据库中查看库名是否存在，存在即备份，不存在即此目录下的所有子目录的 SQL 文件均不会执行（跳过循环）；
3. 备份成功后，才会按顺序执行 SQL 文件；
4. 执行 SQL 文件过程中，若出现报错，则会中断执行，跳出当前循环（为避免后续 SQL 语句依赖前面 SQL）；
5. 因为错误中断了 SQL 文件 清理，因此 workspace 下面还有未执行的 SQL 文件；

- 因此错误处理流程为：

1. 删除已执行过的 SQL 文件/目录；
2. 根据控制台执行过程找到出错的 SQL 语句点；
4. 将出错的 SQL 语句修改正确；
5. 修改正确后，重新执行 Jenkins 任务；
