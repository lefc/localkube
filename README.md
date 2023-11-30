# localkube

`localkube` is a scripted tool that will guide you in setting up a local kubernetes cluster instance via [`minikube`](https://minikube.sigs.k8s.io/docs/start/) alongside some bare services, which in turn allow for having a controlled, live and functioning kubernetes sandbox for learning purposes.

## Changelog

To learn more about changes, please see the [changelog](CHANGELOG.md).


## What does the script do?
The script has 3 main parts:
1. Warmup - this stage checks (and eventually installs) must-have dependencies and tools to use within the scope of the sandboxed cluster. **- DISCLAIMER: INSTALLATION IS NOT SUPPORTED UNDER LINUX ARM ARCHITECTURE (`Homebrew`)**
2. Preparation - this will **clean up** (i.e., it will _delete_) any possible traces of `minikube` which may be running, and any associated `Podman` images and configurations, so as to provide a sterile and controlled environment.
3. Installation - this stage will install, start, and configure the sandbox and other minimal services into the local `minikube` cluster.

## Dependencies

### Overview
`localkube` is designed and tested to run under MacOS Ventura 13.x and above (both Intel and M1/M2 architecture). 

Furthermore, it has also been successfully tested under Linux environments (Ubuntu 20.04 / focal). Please pay attention to the notes provided in the #Installation section, and also make sure you have `curl` installed in your environment previous to executing the installation.

In Windows, there is an underlying assumption that this script should also be able to run under `WSL2`, but expect to have to adjust/port the script under this scenario accordingly.

**Note**: if you are installing `Homebrew` for the first time in your system via `localkube`, the setup process may fail if `Homebrew` cannot be found in the `$PATH`. This is usually exemplified best by the warning message:
```bash
Warning: /home/linuxbrew/.linuxbrew/bin is not in your PATH.
```
Under such cases, `Homebrew` will also provide an automated message with instructions on how to fix the issue. Furthermore, `Homebrew` may also recommend additional steps for completion of the installation,
which vary depending on the distribution in your system. **These steps need to be performed before re-trying the installation process.**, so that `localkube` can  install correctly. After all issues have been resolved, please try again running `setup.sh` normally.

### Structure

`localkube` relies on `Podman` via `containerd` as container engine.

`localkube` will currently install the following versions:
- `K8S_VERSION`: Kubernetes version `1.25.12`

The script relies on the following local dependencies and tools to run successfully, and will be installed automatically upon execution of the script:
- `Homebrew`
- `podman`
- `kubectl`
- `kubectx`
- `minikube`
- `helm`
- `k9s`

Additional dependencies (varying depending on use case):
- `curl` (installed separately)

## What's Inside

Upon successful completion of the install script, a local `minikube` single-node cluster should be provisioned, most prominently with:

- `Kubernetes` version `1.23.14` (this can be changed in the script)
- `coreOS`
- `Kubernetes Control Plane`
- `Kubernetes metrics-server`
- `Kubernetes Dashboard`
- `Prometheus`
- `kube-state-metrics`
- `Grafana`

Additionally, the following tools will be made available for you within your local CLI in order to interact with the cluster: 
- `kubectl`: Kubernetes CLI
- `kubectx/kubens`: Kubernetes Contexts and Namespaces [power tools](https://github.com/ahmetb/kubectx#readme)
- `k9s`: graphical command-line management of k8s resources and cluster 
- `hey`: for generating HTTP load toward any sample application

## Installation

1. Clone this repository
2. Change your CLI directory into the cloned repo:
```bash
cd …/path-to/localkube
```
3. Make sure you grant the necessary execution permissions for the setup script:
```bash
 chmod +x setup.sh
```
4. From within the same directory, run the script:
```bash
./setup.sh
```
5. Pay attention to the interactive prompts within the installer script, and make sure to read any warnings or notices which may be prompted. You may be also prompted for your password during the setup script. 

- **The setup script install logic is designed to be self-contained. Therefore, should you run into issues while executing the script, let the installation finish uninterrupted, then rerun the setup script.**


- **PLEASE BE ADVISED: to avoid potential issues with the pulling of images via minikube or other unexpected networking issues, make sure that you have turned off the developer VPN (if connected) while running the installation script `setup.sh`.**

The current recommended resource configuration is as follows:
- CPU: 4
- Memory: 4GB
- Swap: 2GB
- Virtual Disk size: 20GB

## Understanding the `localkube` cluster
Please refer to the ["What's Inside" section](#whats-inside).

- You can create, modify, or delete any kind of resources using `kubectl`, `kubens`, or `k9s` directly from your CLI after installation.
- To show the bundled `Kubernetes Dashboard` summon it by following the command `minikube dashboard`.
- To be able to interact with some services, you will need to open port-forwarding to each of the desired services. For example, to access the `Grafana` UI, you need to first open up the port forwarding via:
```bash
kubectl -n grafana port-forward svc/grafana 3000:3000
```
then proceed to `http://localhost:3000` in your browser.

## Uninstalling `localkube`

Note: `Homebrew` (local packages) and `Helm` (Kubernetes Charts manager) are dependencies which will also remain in your system after completion of the script. After you are done with using the sandbox, you will have to remove these manually, although it is highly recommended to keep these for continued interaction with _any_ Kubernetes clusters.

To remove `localkube`, run the script, and select the `[u]ninstall` option when prompted.

This will:
- clean up all installed manifests/applications
- shut down and remove the local `minikube` Kubernetes cluster
- purge all related minikube `Podman` images and resources for minikube

This will however **NOT** remove the dependencies installed via `Homebrew`, such as `minikube` itself, the container engines or CLI tooling. 

The reasoning for this: by design, `localkube` will not keep track of which tools or dependencies were present in the system _before_ the setup script was executed. Therefore, this has been left out of the execution logic, so that the user can decide which of these to keep afterwards.

To delete specific and undesired dependencies from `Homebrew`, it suffices to run:
```bash
brew uninstall <package>
```
Note: in case of issues, add the `--force` flag to forcefully remove packages.

To completely remove `Homebrew`, refer to the [official documentation for uninstalling](https://github.com/homebrew/install#uninstall-homebrew).

## Final words

`localkube` was made possible thanks to the documentation of many folks out there. If you wish to have a deeper look:
- [minikube start](https://minikube.sigs.k8s.io/docs/start/) and the [minikube drivers reference](https://minikube.sigs.k8s.io/docs/drivers/)
- [Podman docs](https://keda.sh/docs/2.9/deploy/)
