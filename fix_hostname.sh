#!/bin/bash

set_hostname()
{
	declare -i ec=0
  while true; do
        # new_hostname=$(echo ${1} | grep -P '(?=^.{2,254}$)(^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$)')
		local new_hostname=$1

    if [ -z "$new_hostname" ]; then
    	return 1
    else
      # break free to set hostname, we got correct value
      break
    fi
  done
  
	case "$OS_DISTRO" in 
		centos) 
    	if [ $OS_VERSION -ge 7 ]; then
      	hostnamectl set-hostname $new_hostname --static
      	ec=$?
    	else
      	hostname "$new_hostname"
      	sed -i "s/HOSTNAME=.*/HOSTNAME=$new_hostname/g" /etc/sysconfig/network

      	if [ -n "$( grep "$OLD_HOSTNAME" /etc/hosts )" ]; then
        	sed -i "s/$OLD_HOSTNAME/$new_hostname/g" /etc/hosts
      	else
        	echo -e "$( hostname -I | awk '{ print $1 }' )\t$new_hostname" >> /etc/hosts
      	fi
      	ec=0
    	fi
  	;;
  esac
  
  return $ec
}

# strtolower()
# {
# 	echo "${1}" | tr '[:upper:]' '[:lower:]'
# }

# === MAIN ===
source /etc/icewarpva/va.conf
IWS_INSTALL_DIR='/opt/icewarp'
DATE=$(date)

# determine distro and version
OS_DISTRO='unknown'
if [ -f /etc/centos-release ]; then
  R=$(cat /etc/centos-release)
  #CentOS Linux release 7.1.1503 (Core) 
  OS_DISTRO='centos'
  if [[ $R =~ ([[:digit:]]).([[:digit:]]) ]]; then
    declare -i OS_VERSION=${BASH_REMATCH[1]}
    declare -i OS_MINOR_VERSION=${BASH_REMATCH[2]}
  fi
fi
if [ "$OS_DISTRO" == "unknown" ]; then
	bad "Unknown OS distro, terminating..."
	exit 42
fi


# --------
# get current IceWarp Server primary domain
# IW_P_DOMAIN=$(sh ${IWS_INSTALL_DIR}/tool.sh get domain '*' | tr -s '\n' | tail -n 1 | tr -cd '[:print:]')
# IW_P_DOMAIN=$(strtolower ${IW_P_DOMAIN})

# get current hostname
# C_HOSTNAME=$(strtolower ${C_HOSTNAME})

# decide if update is needed
# if [ "${C_HOSTNAME}" != "${IW_P_DOMAIN}" ]; then
# --------


set_hostname "${1}"
ec=$?
echo "EC: $ec"
	if [ $ec -gt 0 ]; then
		echo "[${DATE}] failed to change hostname from '${C_HOSTNAME}' to '${IW_P_DOMAIN}'" >> "${IWCLD_LOG_DIR}/fix_hostname.log"
	else
		echo "[${DATE}] changed hostname from '${C_HOSTNAME}' to '${IW_P_DOMAIN}'" >> "${IWCLD_LOG_DIR}/fix_hostname.log"
		ec=0
	fi
	exit $ec	
fi
