import jenkins.model.*
pipeline {
  options {
    // 流水线超时设置
    timeout(time: 5, unit: 'HOURS')
    //保持构建的最大个数
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  agent {
    // k8s pod设置
    kubernetes {
      inheritFrom "jenkins-slave-${UUID.randomUUID().toString()}"
      yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins-role: k8s-slave
  namespace: uat
spec:
  containers:
  - name: unzip
    image: ygqygq2/k8s-alpine:v1.28.3
    command:
    - cat
    tty: true
  - name: mysql-client
    image: mysql:8.0.29
    command:
    - cat
    tty: true
    volumeMounts:
    - mountPath: /home/jenkins/agent/backup
      name: data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: mysql-backup-mysqldump
"""
    }
  }

  environment {
    // 全局环境变量
    DB_TYPE="mysql"
    DB_HOST = "mysql-primary.uat"
    DB_OPR = credentials('uat-db-deploy-opr')  // 用户名使用环境变量 DB_OPR_USR 密码使用 DB_OPR_PSW
    DB_PORT = "3306"
  }

  parameters {
    string(defaultValue: './sql', description: 'SQL目录(绝对路径/相对路径均可)',
        name: 'SQL_DIR', trim: true)
    booleanParam(defaultValue: 'true', description: '构建后是否清理 SQL_DIR 目录',
        name: 'SQL_DIR_CLEAN')
    stashedFile '_sql.zip'
  }

  stages {
    stage('发布') {
      steps {
        container('unzip') {
          unstash '_sql.zip'
          sh '''#!/bin/bash -e\n
            # 检查 SQL_DIR 目录是否存在
            [ ! -d "$SQL_DIR" ] && mkdir -p "$SQL_DIR"

            # 解压压缩包
            if [ -s _sql.zip ]; then
              unzip -d $SQL_DIR _sql.zip
              rm -f _sql.zip
            fi
          '''
        }

        container('mysql-client') {
          ansiColor('xterm') {
            sh '''#!/bin/bash -e\n
              # sql 发布
              [ ! -f $WORKSPACE/backup ] && ln -s /home/jenkins/agent/backup $WORKSPACE/backup
              /bin/bash jenkins_deploy_sql.sh

              # 清理 SQL_DIR 目录
              if [ "$SQL_DIR_CLEAN" == "true" ]; then
                tmp_dir="$WORKSPACE/backup/history-sql/$(date +%s)"
                mkdir -p $tmp_dir
                cd $SQL_DIR && [ ! -z "$(ls -A)" ] && mv * $tmp_dir
              fi
            '''
          }
        }
      }
    }
  }
}
