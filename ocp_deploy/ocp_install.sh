#!/bin/bash

#set -vx

# echo "${BASH_SOURCE}"

work_path=$(dirname "${BASH_SOURCE[0]}")

echo "Work path: $work_path"

usage="$0 <-u user> <-p password> [-c config file path] [-f]
-u|-p:  user name | password for rhsm repo
-f   : Flag of force build public key, optional.
-c   : The config_${USER}.sh and pull_secret.json file path
"

script_path=/home/dev-scripts

user=
password=
force=

ocp_config_env() {
  mkdir -p /home/ocp/
}

ocp_config_repo() {
  echo "$#"
  dnf install -y git make docker wget jq dnsmasq
  dnf install -y NetworkManager-initscripts-updown
  dnf install -y go-toolset net-tools bridge-utils
  dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
  dnf install -y ansible
  #You need set your own user/password
  if (($# > 1)); then
    subscription-manager register --serverurl=subscription.rhsm.stage.redhat.com:443/subscription --baseurl=https://cdn.redhat.com --username=$1 --password=$2 --auto-attach
  else
    echo "Skip subscription-manager"
  fi

  dnf install -y git dnsmasq ansible python3-pip

  dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
}

ocp_config_script() {

  if [ -e ${script_path}/config_script_end ]; then
    echo "Exist dev-scripts"
  else
    git clone https://github.com/openshift-metal3/dev-scripts.git ${script_path}
    local filepath=${1:-$work_path}
    cp $filepath/config_${USER}.sh ${script_path}/
    cp $filepath/pull_secret.json ${script_path}/
    cp $filepath/pull_secret.json ${HOME}/
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
  ocp_config_repo $user $password
  ocp_config_script $confpath
  ocp_config_pubkey $force
  cd ${script_path}
  echo "Please copy your pull_secret.json into  ${script_path}"

}

while getopts "fhu:p:" opt; do
  case $opt in
  h)
    echo -e "$usage"
    exit 0
    ;;
  u)
    user="$OPTARG"
    ;;
  f)
    force=1
    ;;
  p)
    password="$OPTARG"
    ;;
  c)
    confpath="$OPTARG"
    ;;
  ? | *)
    echo -e "$usage"
    echo "Unknown parameter"
    exit 1
    ;;
  esac
done

# You may comment if want to call function only
if [ "$0" != "-bash" ]; then
  if [ "user" == "" ] || [ "$password" == "" ]; then
    echo "Please set user and password "
    echo -e "$usage"
    exit 1
  fi
  ocp_config_setup
else
  # test function only 
  echo "Please run ocp_config_setup "
fi
