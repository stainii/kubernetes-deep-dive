# Kubernetes deep dive
One-hour-ish deep dive into the way VDAB leverages containers.

This deep dive will be limited to what VDAB currently uses.

## Init test environment (5 min)
* Go to https://labs.play-with-k8s.com/. Log in with a Github or Dockerhub account.
* Clone this repo: `git clone https://github.com/stainii/kubernetes-deep-dive`
* Initialize the environment by running `cd kubernetes-deep-dive` and `./init.sh`

## Raw Kubernetes
### Pods: I want to run one or multiple containers (5 min)
`kubectl get pods`  
No pods.

`kubectl apply -f my-pod.yml`

`kubectl get pods`  
The pod is there!

`kubectl get pod my-nginx-pod -o yaml`  
Look for `pod ip`. You can curl to this pod ip.

Kill the pod with `kubectl delete pod/my-nginx-pod`.  
Notice that there is no system in place to restart the pod automatically.

### Deployment: I want multiple instances of these pods, and they need to restart when they crash (5 min)
That's what a deployment is for. A deployment (and combined replicaset) make sure that the asked configuration is always respected. Do you want 3 pods alive at all time? It will do its best!

`kubectl get deployments`  
No deployments

`kubectl apply -f my-deployment.yml`

`kubectl get deployments`

`kubectl get pods`

Kill one of the pods with `kubectl delete pod [podName]`.  
You should see that a new one will be created, since the deployment will keep it in that state.

### Services: I want to reach my pods on one address (5 min)
`kubectl get services`  
A default service is available (for running Kubernetes itself), we'll create another one for our Nginx.

`cat my-service.yml`
Let op de selector: 
```yaml
spec:
  selector:
    app: nginx
```

Deze service gaat **op zoek naar deployments** met een **label** dat overeenkomt met `app: nginx`.

`kubectl get deployment my-nginx-deployment -o yaml`

```yaml
labels:
    app: nginx
```

`kubectl apply -f my-service.yml`

`kubectl get services`

```
NAME               TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
kubernetes         ClusterIP   10.96.0.1       <none>        443/TCP   9m19s
my-nginx-service   ClusterIP   10.109.82.233   <none>        80/TCP    4s
```


Within the cluster (within the pods), you can reach the service (and the underlying deployments -> pods) with the service name (http://my-service-name).  
We will prove this in the next step, with a Job.

> [!INFO]
> When you set the type of the service to "NodePort", the service gets a reachable (external) ip on the node.
> There is a better way, however: Ingress/Routes.


## (Cron)Jobs: I want to run a task until it stops

`cat my-job.yml`

* apiVersion: batch/v1: Specifies the API version for a Job resource.
* kind: Job: Indicates that this is a Job resource.
* metadata: Metadata about the Job, such as its name.
* spec: The specification of the Job. It contains:
  * template: The template for the Pod that the Job will create.
    * spec: The specification of the Pod's containers.
    * containers: A list of containers to run in the Pod.
      * name: The name of the container.
      * image: The Docker image for the container. alpine is used here because it's lightweight and includes curl.
      * command and args: The command and arguments to run in the container. Here, it uses sh to run a curl command that prints the result of fetching http://my-nginx-service/.
    * restartPolicy: Never: Ensures that the Pod does not restart. Jobs complete when their Pods exit.
  * backoffLimit: Specifies the number of retries before considering the Job as failed. 4 is a reasonable default.


`kubectl apply -f my-job.yml`

`kubectl get jobs` 

`kubectl logs -f jobs/my-job`

### Ingress/Routes: I want to reach my service from a hostname instead of an IP (2 min)
Ingress is a type of object that binds services to hostnames. It can additionality do url rewriting, header modification, ssl/tls termination, ...

In Openshift, a more specialized type has been added that replaces Ingress functionality: Routes.

Example of an Openshift route:
```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: my-nginx-route
spec:
  host: my-nginx.mydomain.com
  to:
    kind: Service
    name: my-nginx-service
  port:
    targetPort: 80
  tls:
    termination: edge
    certificate: |-
      -----BEGIN CERTIFICATE-----
      MIIDYDCCAkigAwIBAgIJAJC1HiIAZAiIMA0GCSqGSIb3DQEBCwUAMCQxIjAgBgNV
      ... (certificate content)
      -----END CERTIFICATE-----
    key: |-
      -----BEGIN PRIVATE KEY-----
      MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDv... (key content)
      -----END PRIVATE KEY-----
```


### Config maps and secrets: I want to pass configuration properties as environment variables (5 min)
TODO: add env vars to deployment
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
TODO: simpele package installeren zonder templating
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
