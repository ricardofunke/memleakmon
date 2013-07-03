#!/bin/bash

APP_USR=tomcat
MDUMP_FILE_DIR="/app/dumps/memoryDumps"
TDUMP_FILE_DIR="/app/dumps/threadDumps"

JAVA_PID=$(pgrep java); if [[ $? -ne 0 ]]; then echo "No java pid running! Exiting..."; exit 1; fi

watch_mem() {
  jstat -gcutil $JAVA_PID 1 1 | sed '1d' | awk '{print $4}'
}

dump() {
    su $APP_USR -c "jmap -F -dump:format=b,file=\"${MDUMP_FILE_DIR}/jvm-$(hostname)-$(date +%Y%m%d%H).mdump\" $JAVA_PID"
    for n in {1..5}; do su $APP_USR -c "jstack -F $JAVA_PID > \"${TDUMP_FILE_DIR}/jvm-$(hostname)-$n-$(date +%Y%m%d%H).tdump\""; sleep 5; done
    exit 0
}

run() {
  while true; do
    mem_usage=$(watch_mem)

    if [[ $mem_usage -ge 95 ]]; then
      (( verify++ ))
    else
      (( verify=0 ))
    fi

    if [[ $verify -ge 4 ]]; then
      dump
    fi
    sleep 15
  done
}

run
