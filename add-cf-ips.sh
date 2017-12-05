#!/bin/bash
FW_BACKUP=$1
LOG_FILE=$2
PREVIOUS_IPS=$(cat /tmp/cf-iptables-old.txt)

set_new_iplist () {
  curl https://www.cloudflare.com/ips-v4 > /tmp/cf-iptables-new.txt
  NEW_IPS=$(cat /tmp/cf-iptables-new.txt)
}

var_check () {
  if [ -z "$FW_BACKUP" ]; then
    echo -e "$(date +%Y-%m-%d_%H.%M.%S): Backup location not set using default\n"
    FW_BACKUP=/root/iptables-backup$(date +%Y-%m-%d_%H.%M.%S)
  fi

  if [ -z "$LOG_FILE" ]; then
    LOG_FILE=/var/log/fw-update.log
  fi
}

fw_save (){
  echo -e "$(date +%Y-%m-%d_%H.%M.%S): Saving previous iptables to $FW_BACKUP \n" >> $LOG_FILE
  iptables-save > $FW_BACKUP
}

add_cf () {
  if [ -z "$PREVIOUS_IPS" ]; then
    is_different=$(diff <(echo "$PREVIOUS_IPS") <(echo "$NEW_IPS"))
    if [ -z "$is_different" ]; then
      echo -e "$(date +%Y-%m-%d_%H.%M.%S): It looks like the Cloudflare ranges are the same \n" >> $LOG_FILE
      echo -e "$(date +%Y-%m-%d_%H.%M.%S): Exiting\n" >> $LOG_FILE 
      exit 0
    else
      echo -e "$(date +%Y-%m-%d_%H.%M.%S): Looks like the range has changed from:\n $PREVIOUS_IPS \nTo:\n $NEW_IPS \n"
      echo -e "$(date +%Y-%m-%d_%H.%M.%S): Updating iptables\n"
      for ip in $(curl https://www.cloudflare.com/ips-v4); do
        iptables -A INPUT -s $ip --dport https -j ACCEPT 2>&1 >> $LOG_FILE
      done
      did_it_work="$?"
      if [[ "$did_it_work" == 0 ]]; then
        cp /tmp/cf-iptables-new.txt /tmp/cf-iptables-old.txt
      else 
        echo -e "$(date +%Y-%m-%d_%H.%M.%S): Looks like something broke\n" >> $LOG_FILE
        exit 1
      fi
    fi
  fi
}

echo -e "$(date +%Y-%m-%d_%H.%M.%S): Starting Cloudflare IP range update \n" >> $LOG_FILE
ser_new_iplist
var_check
fw_save
add_cf
echo -e "$(date +%Y-%m-%d_%H.%M.%S): Completed run" >> $LOG_FILE
