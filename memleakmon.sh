#!/bin/bash

APP_USR=tomcat
MDUMP_FILE_DIR="/app"
TDUMP_FILE_DIR="/app/threadDumps"

JAVA_PID=$(pgrep java); if [[ $? -ne 0 ]]; then echo "No java pid running! Exiting..."; exit 1; fi

percent_usage() {
  OC=${1%.*}
  OU=${2%.*}
  percent=$(( OU * 100 / OC ))
  echo ${percent}
}


do_monitor() {
  jstat -gcold $JAVA_PID 3000 1 | sed '1d' | awk '{print $3,$4}'
}

run_dumps() {
    su $APP_USR -c "jmap -F -dump:format=b,file=\"${MDUMP_FILE_DIR}/jvm-$(hostname)-$(date +%Y%m%d-%H%M%S).mdump\" $JAVA_PID"
    for n in {1..5}; do su $APP_USR -c "jstack -F $JAVA_PID > \"${TDUMP_FILE_DIR}/jvm-$n-$(hostname)-$(date +%Y%m%d-%H%M%S).tdump\""; sleep 5; done
    exit 0
}

daemonize() {
  while true; do
    mem_usage=$(percent_usage $(do_monitor))

    if [[ $mem_usage -ge 95 ]]; then
      (( verify++ ))
    else
      (( verify=0 ))
    fi

    if [[ $verify -ge 4 ]]; then
      run_dumps
    fi
    sleep 15
  done
}

daemonize
