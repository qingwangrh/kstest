#!/bin/bash

#set -vx

# echo "${BASH_SOURCE}"

WORK_PATH=$(dirname "${BASH_SOURCE[0]}")

echo "Work path: $WORK_PATH"

SCRIPT_PATH=/home/dev-scripts

ocp_config_env() {
  mkdir -p /home/ocp/
}

ocp_config_repo() {
  dnf install -y git make docker wget jq dnsmasq
  dnf install -y NetworkManager-initscripts-updown
  dnf install -y go-toolset net-tools bridge-utils
  dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
  dnf install -y ansible
  subscription-manager register --serverurl=subscription.rhsm.stage.redhat.com:443/subscription --baseurl=https://cdn.redhat.com --username=hawkularqe --password=hawkularqe --auto-attach

  dnf install -y git dnsmasq ansible python3-pip

  dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
}

ocp_config_script() {

  if [ -e ${SCRIPT_PATH}/config_script_end ]; then
    echo "Exist dev-scripts"
  else
    git clone https://github.com/openshift-metal3/dev-scripts.git ${SCRIPT_PATH}
    cp $WORK_PATH/config_root.sh ${SCRIPT_PATH}/
    cp $WORK_PATH/pull_secret.json ${SCRIPT_PATH}/
    cp $WORK_PATH/pull_secret.json ${HOME}/
    touch /home/dev-scripts/config_script_end
  fi
}

ocp_config_pubkey() {

  if [[ -e ~/.ssh/id_rsa ]] && [[ -e ~/.ssh/id_rsa.pub ]]; then
    if (($# < 1)); then
      echo "PUB_KEY key Exist,Skip"
      return
    fi
  fi
  yes | ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''

}

ocp_config_setup() {
  ocp_config_env
  ocp_config_repo
  ocp_config_script
  ocp_config_pubkey
  cd ${SCRIPT_PATH}
}

# You may comment if want to call function only
if [ "$0" != "-bash" ]; then
  ocp_config_setup
else
  echo "Please run ocp_config_setup "
fi

echo "Please copy your pull_secret.json into  ${SCRIPT_PATH}"
