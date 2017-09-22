#!/usr/bin/env bash

# Config parameters #
server1=<server1 ip>
server2=<server2 ip>

ping_timeout=5 # timeout in seconds
misses_failover_threshold=1   # misses count threshold for failing over to backup server
interval=1800s # scan interval
email_notice=true # enable email email notification by setting to "true", disable by setting any other value

account="youraccount"

pubkey_server1=<server1 public signing key>
pubkey_server2=<server2 public signing key>
pubkey_disable=STM1111111111111111111111111111111114T1Anm

export UNLOCK="yourpassphrase" # Unlock the steempy wallet with your passphrase

# RPC server list at https://www.steem.center/index.php?title=Public_Websocket_Servers
rpc1="https://gtg.steem.house:8090"
rpc2="https://steemd.privex.io"
rpc3="https://rpc.steemliberator.com"
rpc4="https://steemd.steemit.com"
rpc5="https://steemd.minnowsupportproject.org"

# End of config

# Functions
function check_rpc {
  # Check RPC nodes status, by querying the total accounts for example.
  getaccount='{"id":0,"method":"get_account_count","params":[]}'
  if [[ `curl --silent $rpc1 --data $getaccount` ]] ; then rpc=$rpc1
    elif [[ `curl --silent $rpc2 --data $getaccount` ]] ; then rpc=$rpc2
    elif [[ `curl --silent $rpc3 --data $getaccount` ]] ; then rpc=$rpc3
    elif [[ `curl --silent $rpc4 --data $getaccount` ]] ; then rpc=$rpc4
  else
    echo "All RPCs are unreachable. Aborting script."
    if [[ $email_notice == "true" ]] ; then sendnotice.py "All RPCs are unreachable. Aborting script." ; fi
    exit
  fi
}
function check_misses {
  misses=$(curl --silent $rpc --data "{\"id\":0,\"method\":\"get_witness_by_account\",\"params\":[\"$account\"]}" | jq -r '.result.total_missed')
  echo $misses
}
# End of functions

check_rpc # check for an active RPC node
echo "Using RPC $rpc"

if [[ $email_notice == "true" ]] ; then
  echo "Email notification is ON"
else
  echo "Email notification is OFF"
fi

init_misses=`check_misses` #witness current total_misses count
echo "[`date`] Initial misses: $init_misses"

# The checking loop
while true ; do
  misses=`check_misses`
  current_pubkey=$(curl --silent $rpc --data "{\"id\":0,\"method\":\"get_witness_by_account\",\"params\":[\"$account\"]}" | jq -r '.result.signing_key')
  
  # Uncomment the next line for testing
  #let misses++
  
  if [[ -z $misses ]] ; then
    echo "[`date`] Failed to fetch misses from $rpc"
    check_rpc # recheck the RPC nodes and use the next operational one
    sleep 10s
    continue
  fi
  
  echo "[`date`] Current misses: $misses | Pubkey: $current_pubkey"
  
  # Servers ping check
  if $(ping -c 1 -W $ping_timeout $server1 &> /dev/null) ; then
    server1_status='up'
  else
    echo "[`date`] Server 1 unreachable"
    server1_status='down'
  fi
  if $(ping -c 1 -W $ping_timeout $server2 &> /dev/null) ; then
    server2_status='up'
  else
    echo "[`date`] Server 2 unreachable"
    server2_status='down'
  fi
  # Ping google to make sure the server running this script is routing properly to the internet
  if $(ping -c 1 -W $ping_timeout google.com &> /dev/null) ; then
    google='up'
  else
    echo "[`date`] Google unreachable"
    google='down'
  fi
  
  # Disable key if both servers are unreachable
  if [[ $server1_status == 'down' ]] && [[ $server2_status == 'down' ]] && [[ $google == 'up' ]] ; then
    echo "[`date`] Server 1 & 2 unreachable, disabling key"
    if [[ $email_notice == "true" ]] ; then sendnotice.py "[`date`] Server 1 & 2 unreachable, disabling key" ; fi
    steempy --node $rpc witnessupdate --witness $account --signing_key $pubkey_disable
    exit
  fi
  
  if [[ $current_pubkey == $pubkey_server1 ]] ; then
    # Server status check
    if [[ $server1_status == 'down' ]] && [[ $server2_status == 'up' ]] && [[ $google == 'up' ]] ; then
      echo "[`date`] Server 1 unreachable, switching to Server 2"
      if [[ $email_notice == "true" ]] ; then sendnotice.py "[`date`] Server 1 unreachable, switching to Server 2" ; fi
      steempy --node $rpc witnessupdate --witness $account --signing_key $pubkey_server2
      #exit
    fi
    # Block miss check
    if [[ $(($misses-$init_misses)) -ge $misses_failover_threshold ]] && [[ $server2_status == 'up' ]] && [[ $google == 'up' ]] ; then
      echo "[`date`] Missed blocks, switching to Server 2"
      if [[ $email_notice == "true" ]] ; then sendnotice.py "[`date`] Missed blocks, switching to Server 2" ; fi
      steempy --node $rpc witnessupdate --witness $account --signing_key $pubkey_server2
      init_misses=$misses # reset the init_misses to the new value
      echo "[`date`] Initial misses reset: $init_misses"
      #exit
    fi
    if [[ $(($misses-$init_misses)) -ge $misses_failover_threshold ]] && [[ $server2_status == 'down' ]] && [[ $google == 'up' ]] ; then
      echo "[`date`] Missed blocks, Server 2 unreachable, disabling key"
      if [[ $email_notice == "true" ]] ; then sendnotice.py "[`date`] Missed blocks, Server 2 unreachable, disabling key" ; fi
      steempy --node "$rpc" witnessupdate --witness $account --signing_key $pubkey_disable
      exit
    fi
  fi
  
  # If server 1 already failed over to server 2, do the following checks.
  if [[ $current_pubkey == $pubkey_server2 ]] ; then
    # Counter added, to avoid multiple witness updates when running the script on multiple machines
    let pubkey2_count++
    if [[ $pubkey2_count == 1 ]]; then
      init_misses=$misses # reset the init_misses after detecting the server 2 fail-over
    fi
    # Status check on server 2
    if [[ $server2_status == 'down' ]] && [[ $google == 'up' ]] ; then
      echo "[`date`] Server 2 unreachable, disabling key"
      if [[ $email_notice == "true" ]] ; then sendnotice.py "[`date`] Server 2 unreachable, disabling key" ; fi
      steempy --node $rpc witnessupdate --witness $account --signing_key $pubkey_disable
      exit
    fi
    # Block miss check on server 2
    if [[ $(($misses-$init_misses)) -ge $misses_failover_threshold ]] && [[ $server2_status == 'up' ]] && [[ $google == 'up' ]] ; then
      echo "[`date`] Missed blocks on Server 2, disabling key"
      if [[ $email_notice == "true" ]] ; then sendnotice.py "[`date`] Missed blocks on Server 2, disabling key" ; fi
      steempy --node $rpc witnessupdate --witness $account --signing_key $pubkey_disable
      exit
    fi
  fi
  
  sleep $interval
  
done
