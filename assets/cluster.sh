# -----------------------------------------------------------------------------------------------------------------------------
# LOCAL DOCKERFILES TO BUILD AND COMPILE
# ONLY MODIFY THIS BLOCK FUNCTION IF YOUR PURPOSE IS TO HAVE TOOLKUBE BUILD AND UPLOAD LOCAL DOCKERFILES INTO THE KUBERNETES CLUSTER,
# VIA A LOCAL (DOCKER/PODMAN) IMAGE REPOSITORY.
# --
# PLEASE SKIP THIS METHOD IF YOU ARE SOURCING IMAGES FROM DOCKERHUB OR ANY OTHER REPOSITORY (E.G. GOOGLE CLOUD, ARTIFACTORY, ETC).
# LIKEWISE IF YOU ARE SOURCHING CHARTS VIA HELM.
# OTHERWISE, JUST INCLUDE THE FOLDER NAMES THAT CONTAIN THE DOCKERFILES YOU WANT TO BUILD - USE ONLY THE NAME OF THAT DIRECTORY!
# -----------------------------------------------------------------------------------------------------------------------------

# array that stores names of folders that have Dockerfiles
DockerfilesToBuild=(
    # app-to-build
)

# -----------------------------------------------------------------------------------------------------------------------------
# KUBERNETES APPLICATIONS AND GENERAL CLUSTER CONFIGURATION
# ONLY MODIFY THIS BLOCK FUNCTION IF YOUR PURPOSE IS TO CHANGE THINGS IN YOUR KUBERNETES CLUSTER.
# -----------------------------------------------------------------------------------------------------------------------------

# Namespaces to create manually in the cluster, besides "default", "kube-system" and others automatically created by HELM or K8S
# Include any namespaces here that you may need for 'kubectl apply'
ClusterNamespaces=(
    grafana
    prometheus
    kafka
    mayfly
)

# Configure cluster, bring in the goodies!
function cluster_setup_checklist() {
    # set working path location for k8s manifests
    DIR_K8S="$DIR/kubernetes"

    # ensure namespaces are created
    printf "\n=> Preparing cluster namespaces....\n"
    namespaces_checklist

    # PREPARE LOCALS, CONFIGURE HELM
    printf "\n=> Initialize Helm....\n"
    helm version
    # example: helm repo add app-name https://awesome-app.github.io/charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add nccloud https://nccloud.github.io/charts
}

# NOTE - THE FOLLOWING BLOCK IS THE ONLY BLOCK BEING CALLED WHEN REDEPLOYING
function cluster_deploy_checklist() {
    # set working path location for k8s manifests
    DIR_K8S="$DIR/kubernetes"

    # update HELM
    helm repo update
    kubectx minikube

    # -----------------------------------
    # -----------------------------------
    # ********* INSTALL CORE ************
    # -----------------------------------
    # -----------------------------------

    # set core working path
    K8S_CORE="$DIR_K8S/core"

    # -----------------------------------
    # DEPLOY K8S CLUSTER CONFIGS
    # -----------------------------------

    # set a default CLI namespace to use for the cluster
    kubens default

    # deploy kube-state-metrics
    printf "\n=> Deploying 'kube-state-metrics' ....\n\n"
    kubectl apply -f $K8S_CORE/kube-state-metrics/ && sleep 30

    # deploy KubeMetrics service
    printf "\n=> Deploying 'metrics-server' ....\n\n"
    kubectl apply  --namespace kube-system -f $K8S_CORE/metrics-server/ && sleep 30

    # -----------------------------------
    # DEPLOY ESSENTIAL TOOLING
    # -----------------------------------

    # deploy prometheus
    printf "\n=> Deploying 'prometheus' ....\n\n"
    kubectl apply --namespace prometheus -f $K8S_CORE/prometheus/ && sleep 40

    # deploy Grafana
    printf "\n=> Deploying 'Grafana' ....\n\n"
    kubectl apply  --namespace grafana -f $K8S_CORE/grafana/ && sleep 10

    # -----------------------------------
    # -----------------------------------
    # ******** INSTALL ADDONS ***********
    # -----------------------------------
    # -----------------------------------

    # set core working path
    K8S_ADDONS="$DIR_K8S/core"

    # -----------------------------------
    # DEPLOY HELM APPLICATIONS
    # -----------------------------------

    ## DEPLOY MAYFLY OPERATOR
    printf "\n=> Deploying 'Mayfly' ....\n\n"
    helm upgrade --install --atomic --cleanup-on-fail mayfly nccloud/mayfly --namespace mayfly --values $K8S_ADDONS/mayfly/values.yaml
    printf "\n\n"

    ## DEPLOY STRIMZI OPERATOR - HELM
    ## COMMENT OUT THIS SECTION IF YOU ARE USING THE YAML DEPLOY VARIANT VIA K8S!!!
    printf "\n=> Deploying 'Strimzi' ....\n\n"
    helm upgrade --install --atomic --cleanup-on-fail strimzi-cluster-operator --namespace kafka --values $K8S_ADDONS/strimzi/helm/values.yaml oci://quay.io/strimzi-helm/strimzi-kafka-operator
    printf "\n\n"

    # DEPLOY KAFKA (nodepool mode, see Strimzi docs)
    printf "\n=> Deploying 'Kafka' ....\n\n"
    kubectl apply --namespace kafka -f $K8S_ADDONS/addons/kafka-strimzi/helm/ && sleep 10

    # -----------------------------------
    # DEPLOY NATIVE YAML 
    # -----------------------------------

    # DEPLOY STRIMZI OPERATOR - YAML
    ## TO SUPPORT YAML MODE - UNCOMMENT THE FOLLOWING SECTION, AND COMMENT OUT THE APROPRIATE LINE IN THE HELM INSTALL
    # printf "\n=> Deploying 'strimzi' ....\n\n"
    # kubectl apply --namespace kafka -f $K8S_ADDONS/strimzi/yaml/ && sleep 30

    # DEPLOY KAFKA (ephemeral mode, see Strimzi docs)
    # printf "\n=> Deploying 'Kafka' ....\n\n"
    # kubectl apply --namespace kafka -f $K8S_ADDONS/kafka-strimzi/yaml/ && sleep 10
}
