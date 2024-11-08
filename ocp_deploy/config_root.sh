#!/bin/bash

# Login https://console-openshift-console.apps.ci.l2s4.p1.openshiftapps.com/ to get token
# Replace with your CI_TOKEN
export CI_TOKEN='This is demo' # notsecret


export WORKING_DIR=/home/ocp
# Login https://quay.io/repository/openshift-release-dev/ocp-release?tab=tags&tag=latest

export OPENSHIFT_RELEASE_IMAGE=quay.io/openshift-release-dev/ocp-release:4.17.2-multi
# Replace with your cluster and domain.
export CLUSTER_NAME="wqvc"
export BASE_DOMAIN="ocp.vm"

# Network config
export PROVISIONING_NETWORK_NAME=brpr
export BAREMETAL_NETWORK_NAME=brbm
export IP_STACK=v4

export NETWORK_TYPE="OVNKubernetes"

# VM Master 2 For low resource 3+ For HA
export NUM_MASTERS=2
export NUM_WORKERS=2
# 8096 12288 16192 32768 65536
export MASTER_MEMORY=16384
export MASTER_DISK=100
export MASTER_VCPU=8
export WORKER_MEMORY=16384
export WORKER_DISK=150
export WORKER_VCPU=8

# VM extra disks optional
export VM_EXTRADISKS=true
export VM_EXTRADISKS_LIST="vdb vdc"
export VM_EXTRADISKS_SIZE="50G"

export NODES_PLATFORM=libvirt

echo "https://console-openshift-console.apps.${CLUSTER_NAME}.${BASE_DOMAIN}"
echo "192.168.111.4 console-openshift-console.apps.${CLUSTER_NAME}.${BASE_DOMAIN} console openshift-authentication-openshift-authentication.apps.${CLUSTER_NAME}.${BASE_DOMAIN} api.${CLUSTER_NAME}.${BASE_DOMAIN} prometheus-k8s-openshift-monitoring.apps.${CLUSTER_NAME}.${BASE_DOMAIN} alertmanager-main-openshift-monitoring.apps.${CLUSTER_NAME}.${BASE_DOMAIN} kubevirt-web-ui.apps.${CLUSTER_NAME}.${BASE_DOMAIN} oauth-openshift.apps.${CLUSTER_NAME}.${BASE_DOMAIN} grafana-openshift-monitoring.apps.${CLUSTER_NAME}.${BASE_DOMAIN}"
