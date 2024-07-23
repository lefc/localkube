# FUNCTIONS

# WARNING! HERE BE DRAGONS!!
# DO NOT MODIFY CODE BELOW UNLESS YOU ARE ABSOLUTELY CERTAIN OF WHAT YOU'RE DOING.
# YOU HAVE BEEN WARNED.

# -----------------------------------------------------------------------------------------------------------------------------

# INITIALIZE VARS
function engine_start() {
    unset DOCKERINSTALL
    unset ivar
    unset input
    unset dd
    unset kd
    unset ns
    unset pd
    unset itb
    unset MACHINE
    unset VM
    unset DIR
    unset DIR_K8S
    unset DIR_DOCKERFILE
    unset MINIKUBE_STATE
    # pre-flight checks
    printf "\n=> localkube v$LOCALKUBE_VERSION\n"
    printf "\n=> If you still haven't done so, please make sure you have made yourself familiar with the documentation before proceeding to the install process.\n"
}

# check homebrew
function preflight_checklist() {
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

# check docker
function docker_checklist() {
    which docker >/dev/null
    if [[ $? != 0 ]] ; then
        DOCKERINSTALL=0 # docker not present
    else
        DOCKERINSTALL=1 #docker is present
    fi
    case $DOCKERINSTALL in
        0) #Docker is not present in the system - throw warning
            #select VM configuration
            printf "\n=> WARNING: dependency 'Docker' not detected! \n=> BE ADVISED: Installation without Docker Engine is still experimental in mac computers equipped with M1 or M2 processors, and are prone to experiencing bugs and unexpected behaviors.\n"
            printf "\n=> In this case, an installation with Podman is still possible, but may cause severe networking issues when running minikube.\n"
            printf "\n=> If obtaining a Docker Desktop license is not possible, this may be yor only choice. Alternatively, you could also try minikube with 'HyperKit' instead of podman (an Xcode installation is required).\n"
            printf "\n=> See 'brew info hyperkit' and Minikube docs at https://minikube.sigs.k8s.io/docs/drivers/hyperkit/ for more information.\n"
            ;;
        1) #Docker is present in the system - no warnings, carry on
            ;;
    esac
}

# Check and install necessary k8s dependencies 
function kube_dependencies_checklist() {
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

# Check if minikube is running
function minikube_checklist() {
    printf "\n=> Checking the status of 'minikube'....\n"
    minikube status | grep Running >/dev/null
    if [[ $? != 0 ]] ; then
        echo "=> Minikube cluster not active."
        MINIKUBE_STATE=0
    else
        minikube status
        MINIKUBE_STATE=1
    fi
}

# Check profile stack for active driver and image build
function images_checklist() {
    printf "\n=> Building Dockerfiles...\n"
    # if docker, (re)build Docker images to minikube
    minikube profile list | grep docker >/dev/null
    if [[ $? == 0 ]] ; then # docker machine
        # rebuild Dockerfiles if present, upload to minikube
        build_images_docker
    fi
    # if docker, (re)build Docker images to minikube
    minikube profile list | grep podman >/dev/null
    if [[ $? == 0 ]] ; then # podman machine
        # rebuild Dockerfiles if present, upload to minikube
        build_images_podman
    fi 
}

# Check and install necessary podman dependencies 
function podman_checklist() {
    printf "\n=> Starting Homebrew install of required packages: "${PodmanDependencies[@]}"\n"
    for pd in ${PodmanDependencies[@]}; do
        which $pd >/dev/null
        if [[ $? != 0 ]] ; then
            printf "\n** Installing dependency '$pd' \n"
            brew install $pd
        else
            printf "\n** Depndency '$pd' detected - skipping install\n"
        fi
    done
    brew cleanup
}

# clean-up socket_vmnet 
function socket_checklist() {
    printf "\n=> Safety first - applying latest network configurations parameters for 'socket_vmnet'...\n"
    sudo brew services restart socket_vmnet
    wait
}

# Create k8s namespaces 
function namespaces_checklist() {
for ns in ${ClusterNamespaces[@]}; do
    printf "\n=> Creating namespace "$ns".... \n"
    kubectl create namespace $ns
done
}

# Build Dockerfiles via Docker and sideload into minikube
function build_images_docker() {
    if [[ ${DockerfilesToBuild} != "" ]] ; then
        printf "\n=> Building now Dockerfiles for the following deployments: \n"
        printf '\t%s|' "${DockerfilesToBuild[@]}";echo && printf "\n"
        for itb in ${DockerfilesToBuild[@]}; do
            printf "\n=> Building Dockerfile for '"$itb"'.... \n"
            DIR_DOCKERFILE="$DIR/images/$itb/Dockerfile"
            docker build --no-cache -t $itb:localkube -f $DIR_DOCKERFILE .
            printf "\n=> Loading image '"$itb:localkube"' into 'minikube'.... \n"
            minikube image load $itb:localkube
            #minikube image build -t $itb:localkube -f $itb/Dockerfile .
        done
    else
        printf "\n=> No Dockerfiles to build, skipping.... \n"
    fi
}

# Build Dockerfiles via Docker and sideload into minikube
function build_images_podman() {
    if [[ ${DockerfilesToBuild} != "" ]] ; then
        printf "\n=> Building now Dockerfiles for the following deployments: \n"
        printf '\t%s|' "${DockerfilesToBuild[@]}";echo && printf "\n"
        for itb in ${DockerfilesToBuild[@]}; do
            printf "\n=> Building Dockerfile for "$itb".... \n"
            DIR_DOCKERFILE="$DIR/images/$itb/Dockerfile"
            podman build --no-cache -t $itb:localkube -f $DIR_DOCKERFILE .
            printf "\n=> Loading image "$itb:localkube" into 'minikube'.... \n"
            minikube image load $itb:localkube
            #minikube image build -t $itb:localkube -f $itb/Dockerfile .
        done
    else
        printf "\n=> No Dockerfiles to build, skipping.... \n"
    fi
}

# clean up any minikube traces before start
function minikube_shutdown_checklist() {
    printf "\n=> Safety first - checking and cleaning possible minikube processes running in the background...\n"
    minikube stop
    wait
    minikube delete
    wait
    pkill minikube
    wait
    minikube status
}

# clean up docker before start
function docker_shutdown_checklist() {
    printf "\n=> checking and cleaning possible Docker processes running in the background...\n"
    docker container stop minikube
    printf "\n=> Purging Docker....\n"
    printf "\n=> Delete container.... " && docker container rm minikube
    printf "\n=> Delete image.... " && docker image prune -a -f
    printf "\n=> Delete network.... " && docker network remove minikube
    printf "\n=> Delete volumes.... " && docker volume rm minikube
}

# clean up podman before start
function podman_shutdown_checklist() {
    printf "\n=> Safety first - checking and cleaning possible podman processes running in the background...\n"
    podman machine stop && podman machine rm -f podman-machine-default
    pkill podman
    wait
}

# start docker
function docker_start_checklist() {
    open --background -a Docker
    # hold while DockerDesktop starts
    sleep 25
}

# start podman
function podman_start_checklist() {
    printf "\n=> Starting Podman...\n"
    podman --version
    printf "\n=> Initializing Podman machine: 4 CPUs, 4096MB memory, 20GB disk, in rootful mode\n"
    podman machine init --now --rootful --cpus=4 --memory=4096 --disk-size=20
}

# start minikube
function minikube_start_checklist() {
    MACHINE=$1
    K8S_VERSION=$2
    printf "\n=> Starting minikube using driver '$MACHINE'....\n"
    minikube version
    case $MACHINE in
        docker)
            printf "\n=> Start localkube installation for Kubernetes version '$K8S_VERSION'\n"
            minikube start --driver $MACHINE --kubernetes-version $K8S_VERSION
            # validate that 'minikube' started successfully - dangerous otherwise!
            kubectx minikube
            if [[ $? != 0 ]] ; then
                # validation failed - exit at once
                printf "\n** FATAL: DEPENDENCY 'minikube' HAS FAILED TO START.\n" && printf "\n=> OPERATION ABORTED - EXITING\n"
                exit 1
            else
                #validation succeeded, install minikube addons and continue
                for mka in ${MinikubeAddons[@]}; do
                minikube addons enable $mka
                done
            fi
            ;;

        podman)
            printf "\n=> Start localkube installation for Kubernetes version '$K8S_VERSION'\n"
            minikube start --driver $MACHINE --kubernetes-version $K8S_VERSION --container-runtime containerd --network socket_vmnet
            # add 'qemu-user-static' dependency - https://github.com/kubernetes/minikube/issues/16530#issuecomment-2001903804
            minikube ssh "sudo apt-get update && sudo apt-get -y install qemu-user-static"
            # validate that 'minikube' started successfully - dangerous otherwise!
            kubectx minikube
            if [[ $? != 0 ]] ; then
                # validation failed - exit at once
                printf "\n** FATAL: DEPENDENCY 'minikube' HAS FAILED TO START.\n" && printf "\n=> OPERATION ABORTED - EXITING\n"
                exit 1
            else
                #validation succeeded, install minikube addons and continue
                for mka in ${MinikubeAddons[@]}; do
                minikube addons enable $mka
                done
            fi
            ;;

    esac
}

# this would make Daenerys Targaryen jealous
function engine_shutdown_checklist() {
    # is docker home?
    if [[ DOCKERINSTALL == 0 ]] ; then
        printf "\n=> Docker not found - skipping warmup...\n"
    else
        # Docker Desktop must be running already before cleaning up
        docker_start_checklist 
    fi
    # stop minikube
    minikube stop
    wait
    minikube delete
    wait
    pkill minikube
    wait
    # purge docker, but only if he's there
    if [[ DOCKERINSTALL == 0 ]] ; then
        printf "\n"          
    else
        docker container stop minikube
        printf "\n** Purging Docker....\n"
        printf "\n** Delete container... " && docker container rm minikube
        printf "\n** Delete image.... " && docker image prune -a -f
        printf "\n** Delete network.... " && docker network remove minikube
        printf "\n** Delete volumes.... " && docker volume rm minikube  
    fi
    # purge podman
    podman machine stop && podman machine rm -f podman-machine-default
    pkill podman
    # purge socket_vmnet
    brew services stop socket_vmnet
}

# pack up and close shop
function parking_checklist() {
    printf "\n\n=> Printing out cluster information.....\n\n"
    printf "\n\n=> CLUSTER DETAILS\n\n" && kubectl cluster-info && printf "\n=> PODS\n\n" && kubectl get pods --all-namespaces && printf "\n=> SERVICES\n\n" && kubectl get services --all-namespaces && printf "\n=> HPA\n\n" && kubectl get hpa --all-namespaces && printf "\n=> Cluster information retreived successfully.\n\n"
    printf "\n\n=> FINAL REMARKS:\n\n"
    printf "\n=> The environment has been setup. It may take a few minutes before all workloads are ready.\n"
    printf "\n=> You can start 'k9s' to access the cluster, or via CLI using 'kubectl'.\n"
    printf "\n=> To see the dashboard, run 'minikube dashboard'.\n"
    printf "\n=> To access Grafana, run 'kubectl -n grafana port-forward svc/grafana 3000:3000', then go to http://localhost:3000 \n"
    printf "\n=> Be advised: 'strimzi-operator' and 'Kafka' may take several minutes to spin up, depending on your hardware configuration.\n"
    printf "\n=> PROCESS COMPLETED.\n"
}