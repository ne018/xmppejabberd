#!/bin/bash

# IMPORTANT: VERIFY ALL VARIABLES BEFORE EXECUTE IT

OLDNODE=ejabberd@localhost
NEWNODE=ejabberd@yourprivatedns
MAINNODE=ejabberd@masterprivatedns
OLDFILE=/tmp/old.backup
NEWFILE=/tmp/new.backup
PATHDATABASE=/opt/ejabberd-18.12.1/database/ejabberd\@localhost
NODECOOKIE=SERVERCOOKIEHERE
EJABBERDCTLPATH=/opt/ejabberd/conf/ejabberdctl.cfg

print_something(){
  tsp=`date +%T`
  echo "$tsp: $1"
}

check_process() {
  echo "$ts: checking $1"
  [ "$1" = "" ]  && return 0
  [ `pgrep -n $1` ] && return 1 || return 0
}

if [ "$1" == "-l" ]; then
  #leave cluster

  while [ 1 ]; do 
    # timestamp
    ts=`date +%T`

    echo "$ts: begin checking..."
    check_process "beam"
    [ $? -eq 1 ] && echo "$ts: starting beam service..." && `ejabberdctl leave_cluster "$NEWNODE" > /dev/null` || break
    sleep 5
  done

  print_something "leave the cluster"

else

  # if not yet started , start ejabberd enforcing the old node name
  #ejabberdctl --node $OLDNODE start

  # now you can finally start ejabberd:
  while [ 1 ]; do 
    # timestamp
    ts=`date +%T`

    echo "$ts: begin checking..."
    check_process "beam"
    [ $? -eq 0 ] && echo "$ts: starting beam service..." && `ejabberdctl --node $OLDNODE start > /dev/null` || break
    sleep 5
  done

  # generate a backup file:
  ejabberdctl --node $OLDNODE backup $OLDFILE
  print_something "generate backup file"

  while [ 1 ]; do 
    # timestamp
    ts=`date +%T`

    echo "$ts: begin checking..."
    check_process "beam"
    [ $? -eq 1 ] && echo "$ts: going to stop beam service..." && `ejabberdctl stop > /dev/null` || break
    sleep 5
  done

  #make sure there aren't files in the Mnesia spool dir
  print_something "making sure no files DCD and DAT in Mnesia spool directory..."
  mkdir -p /var/lib/ejabberd/oldfiles
  mv $PATHDATABASE/*.DCD /var/lib/ejabberd/oldfiles
  mv $PATHDATABASE/*.DAT /var/lib/ejabberd/oldfiles

  while [ 1 ]; do 
    # timestamp
    ts=`date +%T`

    echo "$tsp: begin checking..."
    check_process "beam"
    [ $? -eq 0 ] && echo "$ts: starting beam service..." && `ejabberdctl start > /dev/null` || break
    sleep 5
  done


  # convert the backup to new node name:
  print_something "convert the backup to new node name..."
  ejabberdctl mnesia_change_nodename $OLDNODE $NEWNODE $OLDFILE $NEWFILE


  while [ 1 ]; do 
    # timestamp
    ts=`date +%T`

    echo "$ts: begin checking..."
    check_process "beam"
    [ $? -eq 1 ] && echo "$ts: going to stop beam service..." && `ejabberdctl stop > /dev/null` || break
    sleep 5
  done


  # NOTE: should stop the ejabberd service to avoid error.
  print_something "config updating ERLANG_NODE"
  sed -i -e "s/#ERLANG_NODE=ejabberd@localhost/#ERLANG_NODE=ejabberd@localhost\nERLANG_NODE=$NEWNODE/g" $EJABBERDCTLPATH


  print_something "set node cookies"
  echo "$NODECOOKIE" > /opt/ejabberd/.erlang.cookie
  echo "$NODECOOKIE" > /root/.erlang.cookie

  # you may see an error message in the log files. it's normal do don't worry:


  # now you can finally start ejabberd:
  while [ 1 ]; do 
    # timestamp
    ts=`date +%T`

    echo "$ts: begin checking..."
    check_process "beam"
    [ $? -eq 0 ] && echo "$ts: starting beam service..." && `ejabberdctl start > /dev/null` || break
    sleep 5
  done

  #join cluster
  ejabberdctl join_cluster "$MAINNODE"
  print_something "successfully join in the cluster"

fi
