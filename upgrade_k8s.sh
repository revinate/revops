#!/bin/bash

set -eou pipefail

. ./bash-common-helpers.sh

# Functions

function check_for_update() {
    echo
    kops upgrade cluster | grep Cluster || cmn_die "It looks like your cluster can't be upgraded right now."
}

function warn() {
    cmn_echo_important "${warning_msg}"
    cmn_ask_to_continue "Do you want to continue?"
}

function get_orig_info() {

    cmn_echo_info "OK, continuing. First, we'll get the original state of the cluster."

    kops get ig master-us-west-2a -o yaml > ${TMP_DIR}/master-us-west-2a_ig.orig
    kops get ig master-us-west-2b -o yaml > ${TMP_DIR}/master-us-west-2b_ig.orig
    kops get ig master-us-west-2c -o yaml > ${TMP_DIR}/master-us-west-2c_ig.orig
    #kops get ig nodes -o yaml > ${TMP_DIR}/nodes_ig.orig
    kops get cluster -o yaml > ${TMP_DIR}/cluster.orig

    orig_min=$(grep maxSize ${TMP_DIR}/nodes_ig.orig | awk '{ print $2 }')
    orig_max=$(grep minSize ${TMP_DIR}/nodes_ig.orig | awk '{ print $2 }')
    current_version=$(grep kubernetesVersion ${TMP_DIR}/cluster.orig | awk '{ print $3 }' )

    export kube_orig_min=${orig_min}
    export kube_orig_max=${orig_max}
    export kube_current_version=${current_version}
    #export kube_proposed_version=${proposed_version}
}

function update_kube() {
    cmn_echo_info "Now we'll upgrade the cluster to the newest version."
    cmn_ask_to_continue "Do you want to continue?"
    
    ${DEBUG} kops upgrade cluster --yes
    ${DEBUG}
    mkdir -p ${TMP_DIR}/done
    for file in $(ls ${TMP_DIR}/*_ig.orig); do 
        echo ${file}
        newfile=$(echo ${file} | sed 's/orig/new/')
        echo ${newfile}
        cp ${file} ${newfile}
        cmn_replace_in_files jessie stretch ${newfile}
        kops replace -f ${newfile}
        mv ${newfile} ${TMP_DIR}/done/.
        echo ""
    done
    kops update cluster --yes
}

############################# Vars
curr_context=$(kubectl config current-context)
TMP_DIR="/tmp/${curr_context}_tmp"
mkdir -p ${TMP_DIR}
DEBUG="echo"
warning_msg=$(cat <<EOF
-------------------------------------
WARNING: This script will change the current kubernetes cluster.
Your current context is ${curr_context}.
-------------------------------------

EOF
)
############################# End Vars


function main() {
    #check_for_update
    #warn
    get_orig_info
    #update_kube
    # TODO:
    #double_capacity
    #wait_for_capacity
    #cordon_old_nodes
    ## kubectl get nodes | grep <old version> | awk '{print $1}' | xargs kubectl cordon
    #drain_old_nodes
    ## kubectl get nodes | grep SchedulingDisabled | awk '{print $1}' | xargs kubectl drain --ignore-daemonsets --delete-local-data --force
    #suspend_asg
    ## https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-suspend-resume-processes.html
    ## aws autoscaling suspend-processes --auto-scaling-group-name my-asg
    #terminate_disabled_nodes
    ## Very important we only kill a machine when there are no rns or inguest pods in 'ContainerCreating'- `while | sleep`
    #enable_asg
}

main