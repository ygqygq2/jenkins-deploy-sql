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
  namespace: devops
spec:
  containers:
  - name: db-client
    image: ygqygq2/surrealdb:latest
    command:
    - cat
    tty: true
    volumeMounts:
    - mountPath: /home/jenkins/agent/backup
      name: data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: db-backup
"""
    }
  }

  environment {
    // 全局环境变量
    DB_TYPE="surreal"
    DB_HOST = "surrealdb-tikv.pre"
    DB_OPR = credentials('pre-db-opr')  // 用户名使用环境变量 DB_OPR_USR 密码使用 DB_OPR_PSW
    DB_PORT = "8000"
    DB_NAMESPACE = "ns"
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
        container('db-client') {
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

        container('db-client') {
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
