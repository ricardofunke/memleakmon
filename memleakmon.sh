#!/bin/bash

APP_USR=liferay
MDUMP_FILE_DIR="/opt/dumps/memoryDumps"
MHISTO_FILE_DIR="/opt/dumps/memoryHisto"
TDUMP_FILE_DIR="/opt/dumps/threadDumps"
ERROR_FILE_DIR="/opt/dumps/error"
MELIMIT=90
DBLIMIT=220
LDLIMIT=7

sleep 20

JAVA_PID=$(pgrep java); if [[ $? -ne 0 ]]; then echo "No java pid running! Exiting..."; exit 1; fi

watch_mem() {
  jstat -gcutil $JAVA_PID 1 1 | sed '1d' | awk '{print $4}' | tr , .
}

watch_db() {
  netstat -an | grep ':5432' | grep ESTAB | wc -l
}

watch_load() {
  cat /proc/loadavg | awk '{print $2}' | tr , .
}

dump() {

    local dir=$(date +%Y%m%d%H%M)
    mkdir -p ${MDUMP_FILE_DIR}/${dir} ${MHISTO_FILE_DIR}/${dir} ${TDUMP_FILE_DIR}/${dir} ${ERROR_FILE_DIR}/${dir}
    chown ${APP_USR}: ${MDUMP_FILE_DIR}/${dir} ${MHISTO_FILE_DIR}/${dir} ${TDUMP_FILE_DIR}/${dir} ${ERROR_FILE_DIR}/${dir}

#    su $APP_USR -c "jmap -dump:format=b,file=\"${MDUMP_FILE_DIR}/${dir}/jvm-$(hostname).mdump\" $JAVA_PID 2>> ${ERROR_FILE_DIR}/${dir}/error.log" 
    su -s /bin/bash $APP_USR -c "jmap -histo:live $JAVA_PID > \"${MHISTO_FILE_DIR}/${dir}/jvm-$(hostname).mhisto\" 2>> ${ERROR_FILE_DIR}/${dir}/error.log"
    for n in {1..15}; do su -s /bin/bash $APP_USR -c "jstack $JAVA_PID > \"${TDUMP_FILE_DIR}/${dir}/$n-jvm-$(hostname).thdump\" 2>> ${ERROR_FILE_DIR}/${dir}/error.log"; sleep 10; done

#    exit 0
}

run() {
  while true; do
    #meusage=$(watch_mem)
    dbusage=$(watch_db)
    ldusage=$(watch_load)

    if [[ ( $(echo $dbusage '>=' $DBLIMIT | bc -l) -eq 1 ) || ( $(echo $ldusage '>=' $LDLIMIT | bc -l) -eq 1  ) ]]; then
      (( verify++ ))
    else
      (( verify=0 ))
    fi

    if [[ $verify -gt 1 ]]; then
      dump
      sleep 15
    fi
    sleep 15
  done
}

run
