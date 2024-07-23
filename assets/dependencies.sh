# ARRAYS

# THESE ARRAYS DEFINE LISTS OF DEPENDENCIES TO BE INCLUDED/INSTALLED DURING EXECUTION TIME.
# FEEL FREE TO MODIFY/ADAPT THESE ACCORDINGLY.
# -----------------------------------------------------------------------------------------------------------------------------

# set dependencies for podman
PodmanDependencies=(
    podman
    socket_vmnet
)

# set necessary dependencies for minikube/kubernetes (will be installed via Homebrew)
KubeDependencies=(
    kubectl
    kubectx
    minikube
    helm
    k9s
    hey
)

# set addons for minikube
MinikubeAddons=(
    metrics-server
    dashboard
    #ingress
    #tunnel
)