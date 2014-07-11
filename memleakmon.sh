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
  local heap_size=$(jstat -gccapacity $JAVA_PID 1 1 | sed '1d' | awk '{print $2, "+", $8}' | tr , . | bc)
  local heap_usage=$(jstat -gc $JAVA_PID 1 1 | sed '1d' | awk '{print $3, "+", $4, "+", $6, "+", $8}' | tr , . | bc)
  local percent_usage=$(echo "($heap_usage * 100) / $heap_size)" | bc)
  echo $percent_usage
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

#    su $APP_USR -c "jmap -dump:format=b,file=\"${MDUMP_FILE_DIR}/${dir}/jvm-$(hostname).hprof\" $JAVA_PID 2>> ${ERROR_FILE_DIR}/${dir}/error.log" 
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
