#!/usr/bin/env bash
set -a

link_local_cfg() {
  LCFG=local_${HOSTNAME}_${PROJECT}.cfg
  if [ -f ${LCFG} ]; then
    mv local.cfg local.cfg_old
    ln -s ${LCFG} local.cfg
  else
    echo Error file $LCFG does not exists
  fi
}

switch_project() {
  case ${PROJECT} in
        FEMDK*)   echo FEMDK; link_local_cfg;;
      Beafire*)   echo Beafire; link_local_cfg;;
          IGA*)   echo IGA; link_local_cfg;;
     Overture*)   echo Overture; link_local_cfg;;
             *)   echo "Unknown project ${PROJECT}"; exit 22;;
      esac
}

PROJECT=$1

switch_project
