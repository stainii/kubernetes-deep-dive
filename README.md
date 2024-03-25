# Kubernetes deep dive
One-hour-ish deep dive into the way VDAB leverages containers.

## Init test environment (5 min)
* Go to https://labs.play-with-k8s.com/. Log in with a Github or Dockerhub account.
* Clone this repo: `git clone https://github.com/stainii/kubernetes-deep-dive`
* Initialize the environment by running `cd kubernetes-deep-dive` and `./init.sh`

## Raw Kubernetes
### Pods: I want to run one or multiple containers (5 min)
`kubectl get pods`
No pods.

`kubectl apply -f my-pod.yaml`

`kubectl get pods`
The pod is there!

`kubectl get pod my-nginx-pod -o yaml`
Look for `pod ip`. You can curl to this pod ip.

Kill the pod with `kubectl delete pod/my-nginx-pod`. There is no system in place to restart the pod.

### Deployment: I want multiple instances of these pods, and they need to restart when they crash (5 min)
That's what a deployment is for. A deployment (and combined replicaset) make sure that the asked configuration is always respected. Do you want 3 pods alive at all time? It will do its best!

`kubectl get deployments`
No deployments

`kubectl apply -f my-deployment.yaml`

`kubectl get deployments`

`kubectl get pods`

Kill one of the pods with `kubectl delete pod [podName]`.
You should see that a new one will be created, since the deployment will keep it in that state.

### Services: I want to reach my pods on one address (5 min)
`kubectl get services`
A default service is available (for running Kubernetes itself), we'll create another one for our Nginx.

TODO: services matchen op label

TODO: create service
TODO: curl vanuit pod naar service

Within the cluster (within the pods), you can reach the service (and the underlying deployments -> pods) with the service name (http://my-service-name).

When you set the type of the service to "NodePort", the service gets a reacheable ip on the node. There is a better way, however: Ingress.

### Ingress/Routes: I want to reach my service from a hostname instead of an IP (5 min)
TODO: create ingress en surf ernaar met localhost?

> [!NOTE]
> Configmaps and secrets can also be mounted in different ways. For example: you can mount the yaml as a file on your container.


### Config maps and secrets: I want to pass configuration properties as environment variables (10 min)
TODO: create and mount config map/secret

> [!NOTE]
> Configmaps and secrets can also be mounted in different ways. For example: you can mount the yaml as a file on your container.

> [!NOTE]
> In VDAB, we don't define the values of the secrets in Openshift, but in a Vault. Openshift will download these values and mount them.

## Openshift vs Kubernetes (5 min)
**Kubernetes** is a powerful, flexible foundation for container orchestration, suited for organizations that need customization and have the expertise to manage its complexity.

**OpenShift** builds on Kubernetes to provide an enterprise-ready platform that includes additional features and tools, aiming to simplify the user experience for both developers and operators. It's particularly well-suited for enterprises looking for a comprehensive solution with professional support.

OpenShift includes additional components out of the box, such as a user-friendly web console, integrated development tools, CI/CD  pipeline support, enhanced security features, and built-in monitoring and logging services.

In practice: replace all "kubectl" commands with "oc". Also, we don't use Ingress, we use routes (which is very similar).

## Helm (15 min)
TODO: simpele package maken zonder templating
TODO: nu met templating
TODO: tonen in echt project

## ArgoCD (5 min)
### Git as a Source of Truth
Argo CD uses Git repositories to store the desired state of applications and their environments. It supports various configuration management tools and formats, including Helm, Kustomize, Jsonnet, and plain YAML files.

### Continuous Deployment
Whenever changes are pushed to a Git repository, Argo CD detects these changes and automatically deploys the new versions to the corresponding Kubernetes clusters, ensuring that the live state matches the desired state stored in Git.

### Health Status Monitoring
Argo CD continuously monitors the deployed applications and their resources, providing a visual representation of their health and status. This helps in identifying and resolving issues quickly.

### Rollbacks and Manual Overrides
In case of deployment issues, Argo CD allows for easy rollbacks to previous states. It also supports manual overrides for more control over the deployment process.
