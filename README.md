# Kubernetes deep dive
One-hour-ish deep dive into the way VDAB leverages containers.

This deep dive will be limited to what VDAB currently uses.

## Init test environment (5 min)
* Go to https://labs.play-with-k8s.com/. Log in with a Github or Dockerhub account.
* Click on "start"
* Click on "+ add new instance". You should get a shell.
* **In that shell, execute all the following commands.**
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

> [!NOTE]
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


### Config maps and secrets: I want to pass configuration properties as environment variables (8 min)
#### Config maps
If you `cat my-deployment.yml`, you can see that an env variable has been defined. We can extract this config into a separate "config map". 

`cat my-config-map.yml`  
`cat my-deployment-mounting-from-config-map.yml`

`kubectl apply -f my-config-map.yml`  
`kubectl apply -f my-deployment-mounting-from-config-map.yml`

`kubectl delete job my-job`  
`kubectl apply -f my-job.yml`  
`kubectl logs -f jobs/my-job`

#### Secrets
If the configuration should be kept secret (like passwords), then you should use a Secret instead.

In a default Kubernetes, Secrets are the same as ConfigMaps, with the sole difference that the values have been base64-encoded. This is not so safe, of course.

`cat my-secret.yml`  
`cat my-deployment-mounting-from-secret.yml`

You can add an extension so that secrets are encrypted properly. Also, you can externalize the secrets into a vault, and let Kubernetes download them. 

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
Helm is a **packaging** tool for Kubernetes objects.
It lets you

* bundle Kubernetes configuration files in a tar
* install/uninstall/upgrade the complete package with one command
* allow customisation via a templating engine

### Simplest example

`cd my-nginx-helm-without-values`

`ll`

You see:
* a Chart.yaml file
* a templates folder

`cat Chart.yaml`  
This describes the package that you want to install/distribute.
In its most basic form, this is no more than a name, type and version. 

`ll templates`  
These files should look familiar! They are an exact copy of the Kubernetes files we've toyed with before.

Let's clean up everything we've created manually.
`kubectl delete all --all`

Now, install the package
`helm install my-nginx .`   
`kubectl get all`  
`kubectl logs -f jobs/my-job`

It should all work, installed with only one command. Now imagine pushing this to a repo, sharing with colleagues, ...

Let's clean up before going to the next part.  
`helm uninstall my-nginx`  
`kubectl get all`

### Templating engine

`cd ../my-nginx-helm-with-values`

Imagine you pull a Helm chart from an internet repo. You probably want to have some configuration options!

In the templates folder, you can define "variables" via a Go template syntax. A very simple example: 
`cat templates/my-config-map.yml`

The deployer can define the values for these variables in `values.yaml`.  
`cat values.yaml`

`helm install my-nginx .`

### Libraries, functions, sharing Kubernetes files, ... The sky is the limit.
Helm charts can depend on other Helm charts. You can create "library charts" which only contain functions, variables, ... which helps you customize your own Helm Chart. You can also share Kubernetes files with downstream Helm charts.

Within VDAB, we take this to the extreme. We don't define any Kubernetes file. We extend from a chain of Helm charts, which provide the Kubernetes files and a lot of functions. In our Helm chart, we only need to use the dependency and define our values in `values.yaml`.

Want to see what your dependencies contain? They are located in the `charts` folder!

## ArgoCD (5 min)
### Git as a Source of Truth
Argo CD uses Git repositories to store the desired state of applications and their environments. It supports various configuration management tools and formats, including Helm, Kustomize, Jsonnet, and plain YAML files.

### Continuous Deployment
Whenever changes are pushed to a Git repository, Argo CD detects these changes and automatically deploys the new versions to the corresponding Kubernetes clusters, ensuring that the live state matches the desired state stored in Git.

In VDAB, I think they pull our Helm charts from the Git repo, convert the Helm charts to Kubernetes files via `helm template .`

### Health Status Monitoring
Argo CD continuously monitors the deployed applications and their resources, providing a visual representation of their health and status. This helps in identifying and resolving issues quickly.

### Rollbacks and Manual Overrides
In case of deployment issues, Argo CD allows for easy rollbacks to previous states. It also supports manual overrides for more control over the deployment process.
