#!/bin/bash

APP_USR=tomcat
MDUMP_FILE_DIR="/app"
TDUMP_FILE_DIR="/app/threadDumps"

JAVA_PID=$(pgrep java)

percent_usage() {
  OC=${1%.*}
  OU=${2%.*}
  percent=$(( OU * 100 / OC ))
  echo ${percent}
}


do_monitor() {
  read OC OU <<< $(jstat -gcold $JAVA_PID 3000 1 | sed '1d' | awk '{print $3,$4}')
  echo $OC $OU
}

run_dump() {
    for n in {1..5}; do su $APP_USR -c "jstack $JAVA_PID > \"${TDUMP_FILE_DIR}/liferay-$n-$(hostname)-$(date +%Y%m%d-%H%M%S).tdump\""; sleep 5; done
    su $APP_USR -c "jmap -dump:format=b,file=\"${DUMP_FILE_DIR}/liferay-$(hostname)-$(date +%Y%m%d-%H%M%S).bin\" $JAVA_PID"
    exit 0
}

daemonize() {
  while true; do
    mem_usage=$(percent_usage $(do_monitor))

    if [[ $mem_usage -gt 95 ]]; then
      (( verify++ ))
    else
      (( verify=0 ))
    fi

    if [[ $verify -eq 4 ]]; then
      run_dump
    fi
    sleep 15
  done
}

daemonize
