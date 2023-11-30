#!/usr/bin/env bash

# INIT

unset CURRENT_VERSION
unset input
unset kd
unset ns
unset pd
unset itb
unset K8S_VERSION
unset MACHINE
unset DIR
unset PODMAN_CPU
unset PODMAN_MEM
unset PODMAN_DISK

# set target K8s version to deploy
K8S_VERSION=1.25.12

# podman's minikube VM configuration
# DO NOT CHANGE THESE VALUES UNLESS NECESSARY
# amount of CPU cores to grant
PODMAN_CPU=4
# amount of RAM to allocate (in MB)
PODMAN_MEM=4096
# amount of RAM to allocate (in GB)
PODMAN_DISK=20

# set target namespaces to deploy in the cluster
ClusterNamespaces=(
    grafana
    prometheus
)

# set directories with Dockerfiles to build
# Use only the name of the directory!
ImagesToBuild=(
    #-> insert-directory-name-here (example 'grafana')
)

# set target dependencies for Kubernetes

KubeDependencies=(
    podman
    kubectl
    kubectx
    minikube
    helm
    k9s
    hey
)

# FUNCTIONS

# check homebrew
function check_homebrew() {
which brew >/dev/null
if [[ $? != 0 ]] ; then
    printf "\n=> Homebrew not detected - Starting Homebrew install....\n"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    printf "\n=> Homebrew health check...\n"
    brew doctor
    # check if brew is reconized
    if [[ $? != 0 ]] ; then
        printf "\n=> Homebrew not detected - EXITING...\n"
        exit 1
    else
        printf "\n"
    fi
else
    printf "\n=> Homebrew detected - skipping install\n=> Will now update and upgrade homebrew...\n"
    brew update && brew upgrade
    wait
    printf "\n=> Homebrew health check...\n"
    brew doctor && sleep 2
fi
}

# Check and install necessary k8s dependencies 
function install_kd() {
printf "\n=> Starting Homebrew install of required kubernetes packages: \n"
for kd in ${KubeDependencies[@]}; do
    which $kd >/dev/null
    if [[ $? != 0 ]] ; then
        printf "\n** Installing dependency '$kd' \n"
        brew install $kd
        brew cleanup
    else
        printf "\n** Depndency '$kd' detected - skipping install\n"
    fi
done
}

# Create k8s namespaces 
function kube_genesis() {
for ns in ${ClusterNamespaces[@]}; do
    printf "\n=> Creeating namespace "$ns".... \n"
    kubectl create namespace $ns
    sleep 3
done
}

# Build Dockerfiles via Podman and sideload into minikube
function getmethepicturesofpodman() {
    if [[ ${ImagesToBuild} != "" ]] ; then
        printf "\n=> Building now Dockerfiles for the following deployments: \n"
        printf '\t%s|' "${ImagesToBuild[@]}";echo && printf "\n"
        for itb in ${ImagesToBuild[@]}; do
            printf "\n=> Building Dockerfile for '"$itb"'.... \n"
            podman build --no-cache -t $itb:metrokube -f $itb/Dockerfile .
            printf "\n=> Loading image '"$itb:metrokube"' into 'minikube'.... \n"
            minikube image load $itb:metrokube
            #minikube image build -t $itb:metrokube -f $itb/Dockerfile .
        done
    else
        printf "\n=> No Dockerfiles to build, skipping.... \n"
    fi
}

# clean up any minikube traces before start
function nukeminifromorbit() {
    printf "\n=> Safety first - checking and cleaning possible minikube processes running in the background...\n"
    minikube stop
    wait
    minikube delete
    wait
    pkill minikube
    wait
    minikube status
}

# clean up podman before start
function nukepodmanfromorbit() {
    printf "\n=> Safety first - checking and cleaning possible podman processes running in the background...\n"
    podman machine stop && podman machine rm -f podman-machine-default
    pkill podman
    wait
}

# start podman
function fire_podman() {
    printf "\n=> Starting Podman...\n"
    podman --version
    printf "\n=> Initializing Podman machine: $PODMAN_CPU CPUs, $PODMAN_MEM MB memory, $PODMAN_DISK GB disk, in rootful mode\n"
    podman machine init --now --rootful --cpus=$PODMAN_CPU --memory=$PODMAN_MEM --disk-size=$PODMAN_DISK
}

# start minikube
function fire_minikube() {
    printf "\n=> Starting minikube using driver 'Podman'....\n"
    minikube version
    printf "\n=> Start METROKUBE installation for Kubernetes version '$K8S_VERSION'\n"
    minikube start --driver podman --kubernetes-version $K8S_VERSION --container-runtime containerd
    minikube addons enable metrics-server
    minikube addons enable dashboard

}

# configure cluster, bring in the goodies!
function cluster_setup() {
    # reference local working path
    DIR=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P ) && printf "\n=> Using local directory '"$DIR"'\n"
    # prepare locals, configure helm
    printf "\n=> Initialize Helm....\n"
    helm version
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    printf "\n=> Initializing the metrokube context....\n"
    kubectx minikube
    # create namespaces
    kube_genesis
    printf "\n\n"
    # set a default CLI namespace to use for the cluster
    kubens default
    # deploy kube-state-metrics
    printf "\n=> Deploying 'kube-state-metrics' ....\n\n"
    kubectl apply -f $DIR/kube-state-metrics/ && sleep 30
    # deploy KubeMetrics service
    printf "\n=> Deploying 'kube-state-metrics service' ....\n\n"
    kubectl apply  --namespace kube-system -f $DIR/config/ && sleep 30
    # deploy prometheus
    printf "\n=> Deploying 'prometheus' ....\n\n"
    kubectl apply --namespace prometheus -f $DIR/prometheus/ && sleep 40
    # install KEDA (official docs)
    printf "\n=> Finishing cluster configuration...\n\n" && sleep 20
    # deploy Grafana
    printf "\n=> Deploying 'Grafana' ....\n\n"
    kubectl apply  --namespace grafana -f $DIR/grafana/ && sleep 10
    printf "\n=> Waiting a moment for the cluster to finish creating resources....\n\n" && sleep 20
}

# pack up and close shop
function curtain_call() {
    printf "\n\n=> Printing out cluster information.....\n\n"
    printf "\n\n=> CLUSTER DETAILS\n\n" && kubectl cluster-info && printf "\n=> DEPLOYMENTS\n\n" && kubectl get deployments --all-namespaces && printf "\n=> PODS\n\n" && kubectl get pods --all-namespaces && printf "\n=> SERVICES\n\n" && kubectl get services --all-namespaces && printf "\n=> HPA\n\n" && kubectl get hpa --all-namespaces && printf "\n=> Cluster information retreived successfully.\n\n"
    printf "\n\n=> FINAL REMARKS:\n\n"
    printf "\n=> The environment has been setup. It may take a few minutes before all workloads are ready.\n"
    printf "\n=> You can start 'k9s' to access the cluster, or via CLI using 'kubectl'.\n"
    printf "\n=> To see the dashboard, run 'minikube dashboard'.\n"
    printf "\n=> To access Grafana, run 'kubectl -n grafana port-forward svc/grafana 3000:3000', then go to http://localhost:3000 \n"
    printf "\n=> PROCESS COMPLETED.\n"
}

# this would make Daenerys Targaryen jealous
function scorched_earth_protocol() {
    # stop minikube
    minikube stop
    wait
    minikube delete
    wait
    pkill minikube
    wait
    # purge podman
    podman machine stop && podman machine rm -f podman-machine-default
    pkill podman
    # purge socket_vmnet
    # sudo brew services stop socket_vmnet
}

# START

# pre-flight checks
printf "\n** METROKUBE - Kubernetes Sandbox **\n"
printf "\n=> If you still haven't done so, please make sure you have made yourself familiar with the documentation before proceeding to the install process.\n"
printf "\n=> Performing Pre-Flight checks....\n"
# check homebrew
check_homebrew

# main
while true; do
    printf "\n"
    # interactive loop start
    read -p '==> Please choose one of the following options - [i]nstall [r]einstall [u]ninstall [e]xit: ' input
    case $input in
    [iIrR]*)
        # check/install necessary k8s dependencies 
        install_kd
        MACHINE=podman
        printf "\n=> Will now check and install necessary dependencies for minikube using '$MACHINE'...\n"
        # clean up any minikube traces before start
        nukeminifromorbit
        # clean up podman before start
        nukepodmanfromorbit
        # clean up socket_vmnet
        #wipe_socket_clean
        # prepare VMs
        printf "\n=> Proceeding to Virtual Machine initialisation.... \n"
        # start podman
        fire_podman
        # minikube install
        fire_minikube
        # Build and publish Dockerfile images onto minikube
        getmethepicturesofpodman
        # bring in the goodies
        cluster_setup
        # finish up 
        curtain_call
        break
        ;;
    [uU]*) #uninstall
        printf "\n=> Uninstall is now in progress\n=> This will remove all traces of the metrokube cluster, and shutdown all VMs which may still be running.\n"
        printf "\n=> Please note - dependencies already installed via 'Homebrew': \n" && printf '\t%s|' "${KubeDependencies[@]}";echo && printf "will NOT be automatically uninstalled; these need to be manually removed from your system. See the README for more information.\n"
        printf "\n\n=> Preparing now to uninstall environment....\n"
        # "Kill the masters! Free the slaves!"
        scorched_earth_protocol
        printf "\n=> Checking that 'minikube' is not running anymore...\n"
        minikube status
        printf "\n=> UNINSTALL COMPLETED.\n"
        break
        ;;
    [eE]*) #exit
        printf "\n=> OPERATION ABORTED - EXITING\n"
        exit 1
        ;;
    *) 
        printf "\n--INVALID OPTION - PLEASE CHOOSE ONE OF THE VALID OPTIONS--" >&2
        ;;
    esac
done
