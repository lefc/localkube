#!/usr/bin/env bash

# DANGER ZONE - ONLY CHANGE WHEN CREATING A NEW VERSION!
# set current published version
LOCALKUBE_VERSION=2.0.0

# set target K8s version to deploy
K8S_VERSION=1.27.11

# WARNING! HERE BE DRAGONS!!
# DO NOT MODIFY CODE BELOW UNLESS YOU ARE ABSOLUTELY CERTAIN OF WHAT YOU'RE DOING.
# YOU HAVE BEEN WARNED.

# -----------------------------------------------------------------------------------------------------------------------------

# IMPORTS
for asset in ./assets/*; do
    source $asset
done
# MAIN
engine_start
# reference local working path (root folder) for use in the script
DIR=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P ) && printf "\n=> Using local directory '"$DIR"'\n"
# main engine start
while true; do
    printf "\n"
    # interactive loop start
    read -p $'Please choose one of the following options for cluster install: \n -[b]uild images \n -[d]ocker stack install (recommended) \n -[p]odmnan stack install \n -[r]eload images & redeploy cluster \n -[u]ninstall \n -[e]xit \n=> ' input
    case $input in
    [bB]*) #images
        minikube_checklist
        if [[ $MINIKUBE_STATE == 0 ]] ; then
            # validation failed - return to menu
            printf "\n** FATAL: NO ACTIVE CLUSTER WAS DETECTED!"
            printf "\n** PLEASE ENSURE MINIKUBE IS INSTALLED.\n"
        else
            # validation passed
            printf "\n*VALIDATION PASSED.\n" && printf "\n=> Building Dockerfiles...\n"
            images_checklist
        fi
        ;;
    [dD]*) #docker
        printf "\n=> Performing Pre-Flight checks....\n"
        # check homebrew
        preflight_checklist
        printf "\n=> Proceeding to Virtual Machine initialisation.... \n"
        # check docker
        docker_checklist
        # start docker
        docker_start_checklist
        MACHINE=docker
        # check again if docker is there
        if [[ DOCKERINSTALL != 0 ]] ; then
            printf "\n** Dependency check passed - continuing...\n"
        else
            # validation failed - exit at once
            printf "\n** FATAL: DEPENDENCY '$MACHINE' NOT DETECTED!\n" && printf "\n=> OPERATION ABORTED - EXITING\n"
            exit 1            
        fi
        # check/install necessary k8s dependencies 
        kube_dependencies_checklist
        printf "\n=> Preparing to purge 'Docker'...\n"
        # clean up any minikube traces before start
        minikube_shutdown_checklist
        # clean up docker before start
        docker_shutdown_checklist
        # clean up any possible podman configuration traces (for machines that run both stacks)
        printf "\n=> Will now additionally check uninstall for Podman remnants (this is only as safety for systems running dual stack configurations)...\n"
        podman_shutdown_checklist
        # start docker
        printf "\n=> Starting Docker...\n"
        docker version 
        # minikube install
        minikube_start_checklist $MACHINE $K8S_VERSION
        # Build and publish Dockerfile images onto minikube
        images_checklist
        # prepare the cluster
        cluster_setup_checklist
        # bring in the goodies
        cluster_deploy_checklist
        # final sleep timer needed to allow a moment for the cluster to complete resource creations, only necessary during first install
        printf "\n=> Finishing cluster configuration...\n\n" && sleep 20
        # finish up
        parking_checklist 
        ;;
    [pP]*) #podman
        printf "\n=> Performing Pre-Flight checks....\n"
        # check homebrew
        preflight_checklist
        # check/install necessary k8s dependencies 
        kube_dependencies_checklist
        MACHINE=podman
        printf "\n=> Will now check and install necessary dependencies for '$MACHINE'...\n"
        # install podman stack
        podman_checklist
        # clean up any minikube traces before start
        minikube_shutdown_checklist
        # clean up podman before start
        podman_shutdown_checklist
        # clean up any possible docker configuration traces (for machines that run both stacks)
        printf "\n=> Will now additionally check uninstall for docker remnants (this is only as safety for systems running dual stack configurations)...\n"
        docker_shutdown_checklist
        # clean up socket_vmnet
        socket_checklist
        # start podman
        podman_start_checklist
        # minikube install
        minikube_start_checklist $MACHINE $K8S_VERSION
        # Build and publish Dockerfile images onto minikube
        images_checklist
        # prepare the cluster
        cluster_setup_checklist
        # bring in the goodies
        cluster_deploy_checklist
        # final sleep timer needed to allow a moment for the cluster to complete resource creations, only necessary during first install
        printf "\n=> Finishing cluster configuration...\n\n" && sleep 20
        # finish up 
        parking_checklist
        ;;
    [rR]*) # redeploy cluster
        printf "\n=> Performing Pre-Flight checks....\n"
        # is minikube running?
        minikube_checklist
        if [[ $MINIKUBE_STATE == 0 ]] ; then
            # validation failed - exit at once
            printf "\n** FATAL: NO ACTIVE CLUSTER WAS DETECTED!"
            printf "\n** PLEASE ENSURE MINIKUBE IS RUNNING AND THE KUBERNETES CLUSTER IS ACTIVE.\n" && printf "\n=> OPERATION ABORTED - EXITING\n"
            exit 1
        else
            # validation passed
            printf "\n*VALIDATION PASSED.\n"              
            # redeploy cluster deployments
            printf "\n=> Redeploying Kubernetes cluster....\n"
            cluster_deploy_checklist
            printf "\n\n=> Printing out cluster information.....\n\n"
            printf "\n\n=> CLUSTER DETAILS\n\n" && kubectl cluster-info && printf "\n=> PODS\n\n" && kubectl get pods --all-namespaces && printf "\n=> SERVICES\n\n" && kubectl get services --all-namespaces && printf "\n=> HPA\n\n" && kubectl get hpa --all-namespaces && printf "\n=> Cluster information retreived successfully.\n\n"
            printf "\n=> PROCESS COMPLETED.\n"
        fi
    ;;
    [uU]*) #uninstall
        printf "\n=> Uninstall is now in progress\n=> This will remove all traces of the localkube cluster, and shutdown all VMs which may still be running.\n"
        printf "\n=> Please note - dependencies already installed via 'Homebrew': \n" && printf '\t%s\n' "${KubeDependencies[@]}";echo && printf '\t%s\n' "${PodmanDependencies[@]}";echo && printf "will NOT be automatically uninstalled; these need to be manually removed from your system. See the README for more information.\n"
        printf "\n\n=> Preparing now to uninstall environment....\n"
        # "Kill the masters! Free the slaves!"
        engine_shutdown_checklist
        printf "\n=> Checking that 'minikube' is not running anymore...\n"
        minikube status
        printf "\n=> UNINSTALL COMPLETED.\n"
        ;;
    [eE]*) #exit
        exit 1
        ;;
    *) 
        printf "\n--INVALID OPTION - PLEASE CHOOSE ONE OF THE VALID OPTIONS--" >&2
        ;;
    esac
done