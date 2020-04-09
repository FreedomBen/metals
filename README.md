# MeTaLS (mTLS)

[![Docker Repository on Quay](https://quay.io/repository/freedomben/metals/status)](https://quay.io/repository/freedomben/metals)  ![GitHub](https://img.shields.io/github/license/freedomben/metals)  ![Version](https://img.shields.io/badge/Version-v0.2.0-green)

Link to source repository:  [https://github.com/FreedomBen/metals](https://github.com/FreedomBen/metals)

MeTaLS uses a [containerized](https://opensource.com/resources/what-are-linux-containers) instance of [nginx](https://www.nginx.com/) to easily add [mTLS](https://en.wikipedia.org/wiki/Mutual_authentication) services to any backend service.  All you have to do is provide some configuration information to the container (done through environment variables), and it will configure itself dynamically at runtime.  Full example project that implements MeTaLS available for reference [here](https://github.com/FreedomBen/metals-example).

**Pre-built images are available here**:

* Quay:  [quay.io/freedomben/metals:latest](https://quay.io/repository/freedomben/metals)
* Docker hub:  [docker.io/freedomben/metals:latest](https://hub.docker.com/repository/docker/freedomben/metals)

## Quick Links

* [Full example project](https://github.com/FreedomBen/metals-example)
* [How it Works](#how-it-works)
* [Detailed Usage](#usage)
    * [Pre-requisites](#pre-requisites)
    * [Configuring your app](#configuring-your-app)
    * [Configuring MeTaLS](#configuring-metals)
    * [Pre-built Images](#pre-built-images)
    * [Deploying Together](#putting-your-app-and-metals-together-like-chocolate-and-peanut-butter)
* [Variable reference](#required-variables)
* [Frequently Asked Questions (FAQs)](#faqs)

## Quick Start

At a high level, to add mTLS to your [OpenShift](https://www.openshift.com/) or [Kubernetes](https://kubernetes.io/) application with this project, assuming you already have a working [Deployment](https://docs.openshift.com/container-platform/4.1/applications/deployments/what-deployments-are.html) or [DeploymentConfig](https://docs.openshift.com/container-platform/4.1/applications/deployments/what-deployments-are.html#deployments-and-deploymentconfigs_what-deployments-are), you will:

1. Obtain TLS cert and key for your service, and the trust chain for clients who should be allowed in
1. Add a container to your Deployment's containers array so that the official MeTaLS image gets run inside your application Pods
1. Configure the required environment variables to pass in your certificates
1. Profit!

More detailed information on the above is available in this document.

If you would like to see a full example app that uses MeTaLS to add mTLS capabilities, there is [a full example application here](https://github.com/FreedomBen/metals-example).  A deployable YAML file (complete with health checks) is available [here](https://github.com/FreedomBen/metals-example/blob/master/examples/metals-example-ocp-secrets-health-checks.yaml).

## Why you want this and how it works

[mTLS (or mutual TLS)](https://en.wikipedia.org/wiki/Mutual_authentication) is like regular TLS where the client verifies the identity of the server, but mTLS add verification of the _client's_ identity as well (hence the "mutual"). In traditional TLS configurations the server doesn't care who the client is, but in many security conscious and enterprise environments this is undesirable.

Some applications have a requirement for mTLS, and while there are numerous libraries to help provide this, it can be tedious and/or error prone to set up your own from scratch.  Additionally, having a stand-alone solution that can be dropped into any service helps to reduce bugs, increase consistency, reuse code ([DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself)), and simplify auditing.

Nginx is a mature, performant reverse proxy server that has a well-tested mTLS implementation.  While you can do it yourself, it is generally easier, cheaper, and smarter to reach for an existing, well-tested solution.

### How it works

This project/image mainly consists of a startup script ([start.sh](https://github.com/FreedomBen/metals/blob/master/start.sh)) and a [Dockerfile](https://docs.docker.com/engine/reference/builder/).  At startup, the script will:

1.  Examine the environment variables provided
1.  Write keys and certs to file for nginx to consume
1.  Generate an [nginx config](https://www.nginx.com/resources/wiki/start/topics/examples/full/) file
1.  Start nginx

The script has quite a few validation steps to help you identify and debug errors without needing to dig into the script yourself.

The basic recommended usage for this image is inside of a [Pod](https://kubernetes.io/docs/concepts/workloads/pods/pod-overview/) , using the [sidecar](https://blog.openshift.com/patterns-application-augmentation-openshift/) (see also: [here](https://www.magalix.com/blog/the-sidecar-pattern) and [here](https://aws.amazon.com/blogs/compute/nginx-reverse-proxy-sidecar-container-on-amazon-ecs/) for more info on sidecars) with an instance of your service.  Note that Pods are not limited to Kubernetes. They can be used on Linux with tools like [Podman](https://podman.io/) as well.  Example [YAML](https://github.com/FreedomBen/metals-example/blob/master/examples/metals-example-deployment-production.yaml) is provided to deploy this to [OpenShift](https://www.openshift.com/) or any compatible [Kubernetes](https://kubernetes.io/).  See also the example project ([metals-example](https://github.com/FreedomBen/metals-example)) that you can use for reference.

Nginx is configured automatically (based on environment variables supplied to it) in [reverse proxy](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/) mode and is loaded with the correct configuration automatically.  This is all done on initialization (runtime) before serving traffic.

[Certificates](https://en.wikipedia.org/wiki/Public_key_certificate) are expected to come from [environment variables](https://opensource.com/article/19/8/what-are-environment-variables).

For more information about the sidecar pattern, I recommend the official [OpenShift blog on the subject](https://blog.openshift.com/patterns-application-augmentation-openshift/) as well as [this blog on the Sidecar Pattern](https://www.magalix.com/blog/the-sidecar-pattern) and [this post with some good reasons to use a sidecar](https://aws.amazon.com/blogs/compute/nginx-reverse-proxy-sidecar-container-on-amazon-ecs/).

Here is a diagram of the simplest possible usage (a local Pod running on a single machine.  This is what you might use in development with a tool like [Podman](https://podman.io) for example):

<img src="https://github.com/FreedomBen/metals/raw/master/docs/images/metals-basic.png" alt="MeTaLS Basic Diagram" width="450" />

If you are going to deploy to [Kubernetes](https://kubernetes.io) or [OpenShift](https://www.openshift.com/), your architecture may look more like this:

<img src="https://github.com/FreedomBen/metals/raw/master/docs/images/metals-k8s.png" alt="MeTaLS Kubernetes Diagram" width="800" />

### What About Health Checks?

If the entity doing the health checks has a valid certificate (per the client trustchain), then nothing special need to be done to support health checks.

However, if the health checker does *not* have a valid certificate, then health checks will fail because nginx will deny access and will not proxy the request.  To work around this you can set some variables, and then the startup script that generates the `nginx.conf` file will create entries allowing the paths that you specify to get through.  The only caveat is that health checks *cannot* reuse the same port.  If the health checker is accessing your application through an OpenShift Service or Routes, you will need to expose both ports.  The service behind the proxy can continue to use the same port and can remain agnostic about the ports mTLS is using.

## Usage

### Overall

Configuration is done by passing in environment variables.  See below if you need to customize the [nginx config](https://www.nginx.com/resources/wiki/start/topics/examples/full/).

To use, add a container with this image to your pod definition.  There is an example service called [metals-example](https://github.com/FreedomBen/metals-example) you can use for reference.

### Pre-requisites

If you want to use this with TLS, you will need some certificates and a private key.  You will need:

1.  A private key for your backend service
1.  A public certificate for your backend service (this will be used when creating an [OpenShift Route](https://docs.openshift.com/container-platform/3.9/dev_guide/routes.html) if your service is to be exposed outside the cluster)
1.  Trust chain for your public certificate (Includes all Intermediate CA and root CA certificate that were used to sign the public certificate for your service) (Order matters!  Intermediate first then Root)
1.  Trust chain for your client certificate(s).  Clients presenting a valid certificate signed by one of these CAs will be authenticated and their requests will be proxied to the backend service.

Hint:  Make sure your certs _and all CAs in the trust chain_ have client or server auth enabled (respectively) as a purpose, otherwise the certs will not be accepted by nginx.  If you're not sure, use this command:

```bash
openssl x509 -in <certificate-or-ca-file> -text
```

and look for a section like this in the output:

```
X509v3 Extended Key Usage:
    TLS Web Server Authentication, TLS Web Client Authentication
```

If you're verifying a client cert, it should have `TLS Web Client Authentication` or `TLS Web Server Authentication` for server certs.  It's OK to have both if you want to use your certificates interchangeably.

### Configuring your app

Configure your app to bind to 127.0.0.1:8080.  If you want to use a different port other than 8080, you can use the [optional variable](#optional-variables) `METALS_FORWARD_PORT` to change the port that MeTaLS will forward traffic to.

Important note:  You **MUST** bind to 127.0.0.1 inside the Pod in order to ensure that outside traffic cannot circumvent MeTaLS and talk directly to your application.  Many frameworks bind to 0.0.0.0 (or a specific interface IP) by default, but this will significantly undermine the security that MeTaLS provides, so double check this setting in your application!

* Interface: 127.0.0.1
* Port: 8080

### Configuring MeTaLS

All configuration of MeTaLS is done through environment variables.  Environment variables are a flexible way to do configuration because you can populate them from a number of different sources, based on how your application is set up and what your preferences are.  For example environment variables can come from dot-env files, OpenShift Secrets, ConfigMaps, property files, and numerous other sources.

All MeTaLS variables are namespaced with `METALS_` at the beginning to avoid conflicting with other settings.  This way you can commingle your MeTaLS settings with other sources of variables, if you choose.

#### Required Variables

As long as you accommodate the [default settings](#default-settings), the only required variables are the private key and the certificate and trust chains.

| Variable                     | Required | Description |
|------------------------------|----------|------------------------------------------------------------------------|
| `METALS_PRIVATE_KEY`:        | Yes      | Private key of the service in PEM format |
| `METALS_PUBLIC_CERT`:        | Yes      | Public certificate of the service in PEM format |
| `METALS_SERVER_TRUST_CHAIN`: | Sort of  | If you put the whole trust chain in METALS_PUBLIC_CERT then you can omit this, otherwise it is required |
| `METALS_CLIENT_TRUST_CHAIN`: | Yes      | Trust chain for valid clients in PEM format |


#### Optional Variables

If you want to customize the behavior of MeTaLS, or if you need finer grained control over the settings, you can utilize these optional variables to fine tune the behavior of MeTaLS.  These are all *String* values.

| Variable                     | Required | Default Value      | Description |
|------------------------------|----------|--------------------|-------------|
| `METALS_DEBUG`               | No       | `false`            | Set to `true` for additional logging output |
| `METALS_DEBUG_UNSAFE`        | No       | `false`            | Set to `true` for great logging, but risks printing out secrets to the console (which in OpenShift ends up in log files).  This is really useful in dev environments |
| `METALS_TRACE`               | No       | `false`            | Set to `true` to get an absurd amount of logging (basically every command will be printed before being run).  You may want to combine this with METALS_DEBUG=true to get every possible message.<br>**WARNING: Do not use METALS_TRACE in production as some sensitive data may be printed to the logs** |
| `METALS_LISTEN_PORT`         | No       | `8443`             | If you don't want mTLS nginx to listen on `8443`, set this to the port you want.  It must be above `1024` or else the nginx process won't have permission in the container to bind to it |
| `METALS_FORWARD_PORT`        | No       | `8080`             | If your application doesn't listen on `8080`, set this to the correct port for your application. |
| `METALS_PROXY_PASS_HOST`     | No       | `127.0.0.1`        | set to hostname of backend service |
| `METALS_PROXY_PASS_PROTOCOL` | No       | `http`             | set to `http` or `https` |
| `METALS_SSL_SESSION_TIMEOUT` | No       | `6m`               | will be passed to nginx as `ssl_session_timeout` |
| `METALS_SSL_PROTOCOLS`       | No       | `TLSv1.2 TLSv1.3`  | Versions of TLS that MeTaLS will allow clients to use.  (will be passed to nginx as `ssl_protocols`) |
| `METALS_SSL_CIPHERS`         | No       | `HIGH:!aNULL:!MD5` | Defaults to `HIGH:!aNULL:!MD5`.  (will be passed to nginx as `ssl_ciphers` |
| `METALS_SSL_VERIFY_DEPTH`    | No       | `7`                | will be passed to nginx as `ssl_verify_depth`.  If you have long trust chains, you may need to increase this |
| `METALS_SSL`                 | No       | `on`               | **WARNING: If you set this to `"off"` TLS will be completely disabled, meaning all traffic is plain text!**<br>Defaults to `"on"`.  Disabling SSL can be very useful for debugging, but don't forget to re-enable it before deploying |
| `METALS_SSL_VERIFY_CLIENT`   | No       | `on`               | **WARNING: If you set this to `"off"` the client will not be verified, meaning this is just regular TLS and not mTLS!**.<br>Defaults to `"on"`.  Disabling client authentication can be very useful for debugging, but don't forget to re-enable it unless you only need TLS |
| `METALS_SLEEP_ON_FATAL`      | No       | `""`               | Setting this to an integer value will cause the container to sleep for this many seconds after encountering a fatal error.  This is useful for keeping a pod alive while you inspect logs to determine what went wrong |

#### Skipping Client Auth for certain paths (such as Health Checks)

If you need to allow certain paths through without client authentication, you can use these variables to provide a whitelist:

| Variable                                      | Required | Default Value    | Description |
|-----------------------------------------------|----------|-------------------------------|-------------|
| `METALS_SKIP_CLIENT_AUTH_PATH`<br />`METALS_SKIP_CLIENT_AUTH_PATH_0`<br />`METALS_SKIP_CLIENT_AUTH_PATH_2`<br />`METALS_SKIP_CLIENT_AUTH_PATH_3`       | No       | `""`               | Setting this to a path will cause the container to proxy requests to this path to the backend *without performing client authentication*.  This is useful for health check endpoints for example, where the health checker (such as a Kubelet) does not have a valid certificate |
| `METALS_SKIP_CLIENT_AUTH_LISTEN_PORT`         | No       | `""`               | Optional port number to use for health check paths that skip client auth.  Defaults to 9443. |
| `METALS_HEALTH_CHECK_PATH`<br />`METALS_HEALTH_CHECK_PATH_0`<br />`METALS_HEALTH_CHECK_PATH_1`<br />`METALS_HEALTH_CHECK_PATH_2`<br />`METALS_HEALTH_CHECK_PATH_3`     | No       | `""`               | Setting this to a path will cause the container to proxy requests to this path to the backend *without performing client authentication*.  This is useful for health check endpoints for example, where the health checker (such as a Kubelet) does not have a valid certificate |
| `METALS_HEALTH_CHECK_LISTEN_PORT`             | No       | `9443`             | Optional port number to use for health check paths that skip client auth.  Defaults to 9443. |

You may notice that `METALS_SKIP_CLIENT_AUTH_PATH` and `METALS_HEALTH_CHECK_PATH` do the same thing.  Good observation!  This is by design to allow you to choose the one with more semantic meaning for you.  I tried to choose self-documenting variable names that would describe their function.  If you are skipping client authentication for health check reasons, you may wish to choose the `METALS_HEALTH_CHECK_PATH` version as it's more self-documenting.  Ultimately however, the choice is up to you.

#### Vault Integration

If you use [Hashicorp Vault](https://www.vaultproject.io/) for storing secrets, MeTaLS can pull the service private key and/or certificates down from Vault upon initialization.

MeTaLS provides two options for authenticating with Vault:

1.  Provide [a `VAULT_TOKEN`](https://www.vaultproject.io/docs/concepts/tokens/) directly
1.  Use the [Kubernetes Auth Method](https://www.vaultproject.io/docs/auth/kubernetes/) to authenticate using the [Kubernetes Service Account](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/)

The service account method is recommended if available, as it removes the need to manage the token, and eliminates the risk of token expiration.

If you wish to use the Vault integration, provide a way for MeTaLS to authenticate to Vault:

| Variable                | Required | Default               | Description |
|-------------------------|----------|-----------------------|-------------------------------|
| `VAULT_TOKEN`:          | Yes      |                       | API token that can be used to retrieve Vault secrets |
|     or                  |          |                       |  |
| `VAULT_ROLE`:           | Yes      |                       | Vault role to use when authenticating to Vault using the Kubernetes service account |
| `VAULT_KUBE_AUTH_PATH`: | No       | `v1/kubernetes/login` | Path where Vault's Kubernetes auth endpoint is listening |

And tell MeTaLS where you put your key and/or certificates:

| Variable                         | Required | Description |
|----------------------------------|----------|-------------|
| `VAULT_ADDR`:                    | Yes      | URL for Vault.  Example:  https://vault.example.com |
| `VAULT_NAMESPACE`:               | No       | If using Enterprise Vault and namespaces, provide the namespace here. If not using namespaces then leave this empty |
| `METALS_VAULT_PATH`:             | Yes      | Path to the secret that contains the key and/or certs.  [If you use different vault paths](#If-you-use-different-Vault-paths-for-some-secrets) for some secrets, see [below](#If-you-use-different-Vault-paths-for-some-secrets).  Example: secret/data/metals |
| `METALS_PRIVATE_KEY_VAULT_KEY`:  | Yes      | Vault key where the service's private key is stored.  Example:  "private_key" |
| `METALS_PUBLIC_CERT_VAULT_KEY`:  | Yes      | Vault key where the service's public cert is stored.  Example:  "public_cert" |
| `METALS_SERVER_CHAIN_VAULT_KEY`: | Yes      | Vault key where the server's trust chain is stored.  Example:  "server_chain" |
| `METALS_CLIENT_CHAIN_VAULT_KEY`: | Yes      | Vault key where the client's trust chain is stored.  Example:  "client_chain" |


##### If you use different Vault paths for some secrets

If you use different Vault paths for some of the secrets, you can specify them individually by using these variables.  If these variables are populated, they will take precedence for the corresponding secret over `METALS_VAULT_PATH`

| Variable                          | Required | Description |
|-----------------------------------|----------|-------------|
| `METALS_PRIVATE_KEY_VAULT_PATH`:  | No       | Vault key where the service's private key is stored.  Example:  secret/data/metals/key |
| `METALS_PUBLIC_CERT_VAULT_PATH`:  | No       | Vault key where the service's public cert is stored.  Example:  secret/data/metals/cert |
| `METALS_SERVER_CHAIN_VAULT_PATH`: | No       | Vault key where the server's trust chain is stored.  Example:  secret/data/metals/server_chain |
| `METALS_CLIENT_CHAIN_VAULT_PATH`: | No       | Vault key where the client's trust chain is stored.  Example:  secret/data/metals/client_chain |


### Pre-Built Images

There are pre-built images available on quay.io and Docker Hub.  The default images use [dumb-init](https://github.com/Yelp/dumb-init) as PID 1, but if you prefer [tini](https://github.com/krallin/tini) there is an image available built on tini.  The only difference between the dumb-init and tini images are the PID 1.

For more information on PID 1 and containers, The [OpenShift Image Guidelines](https://docs.openshift.com/enterprise/3.0/creating_images/guidelines.html) are helpful.  There is a good blog post [Docker and the PID 1 zombie reaping problem](http://blog.phusion.nl/2015/01/20/docker-and-the-pid-1-zombie-reaping-problem/), as well as [Demystifying the init system (PID 1)](https://felipec.wordpress.com/2013/11/04/init/).

#### [dumb-init](https://github.com/Yelp/dumb-init) based images:

* Quay:  [quay.io/freedomben/metals:latest](https://quay.io/repository/freedomben/metals)
* Quay:  [quay.io/freedomben/metals-dumb-init:latest](https://quay.io/repository/freedomben/metals-dumb-init) (Identical to above, just explicitly contains "dumb-init" in the image name)
* Docker hub:  [docker.io/freedomben/metals:latest](https://hub.docker.com/repository/docker/freedomben/metals)
* Docker hub:  [docker.io/freedomben/metals-dumb-init:latest](https://hub.docker.com/repository/docker/freedomben/metals-dumb-init) (Identical to above, just explicitly contains "dumb-init" in the image name)

#### [tini](https://github.com/krallin/tini) based images:

* Quay:  [quay.io/freedomben/metals-tini:latest](https://quay.io/repository/freedomben/metals-tini)
* Docker hub:  [docker.io/freedomben/metals-tini:latest](https://hub.docker.com/repository/docker/freedomben/metals-tini)

### Putting your app and MeTaLS together (like chocolate and peanut butter)

Now that your app and MeTaLS are both configured, it's time to put them together!

The recommended configuration is inside a [Pod](https://kubernetes.io/docs/concepts/workloads/pods/pod-overview/), using the [sidecar](https://blog.openshift.com/patterns-application-augmentation-openshift/) pattern.

Whether you use Podman on a single Linux box or you use OpenShift/Kubernetes for massive scale, each instance of your app will have an instance of MeTaLS proxying for it.

If using OpenShift, you will want to define your Pod in a container spec inside of a [Deployment](https://docs.openshift.com/container-platform/4.1/applications/deployments/what-deployments-are.html) or [DeploymentConfig](https://docs.openshift.com/container-platform/4.1/applications/deployments/what-deployments-are.html#deployments-and-deploymentconfigs_what-deployments-are).  There's a more complete example available [here](https://github.com/FreedomBen/metals-example/blob/master/examples/metals-example-ocp-secrets.yaml).

If using Podman either locally or on a single server deployment, you could use something like this (substitute your own values appropriately):

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: metals-example
spec:
  containers:
    # Replace this image with your own app image
  - image: quay.io/freedomben/metals-example:latest
    name: metals-example
    imagePullPolicy: Always
  - image: quay.io/freedomben/metals:latest
    name: metals
    imagePullPolicy: Always
    ports:
    - containerPort: 8443
      protocol: TCP
    env:
    - name: METALS_PRIVATE_KEY
      value: |-
        -----BEGIN RSA PRIVATE KEY-----
        ...
        -----END RSA PRIVATE KEY-----
    - name: METALS_PUBLIC_CERT
      value: |-
        -----BEGIN CERTIFICATE-----
        ...
        -----END CERTIFICATE-----
    - name: METALS_SERVER_TRUST_CHAIN
      value: |-
        -----BEGIN CERTIFICATE-----
        ...
        -----END CERTIFICATE-----
    - name: METALS_CLIENT_TRUST_CHAIN
      value: |-
        -----BEGIN CERTIFICATE-----
        ...
        -----END CERTIFICATE-----
```

#### Interface binding in your application

I've already mentioned this, but it bears repeating.

You will need to make sure that your application is *not binding to `0.0.0.0`*.  Your application should bind to `127.0.0.1`.  Because of how pod network namespace is shared, if you app binds to `0.0.0.0` then *it will be accessible directly from outside the pod*.  Anything running in the cluster that could find or guess your pod's IP address would be able to circumvent your mTLS access control layer.  In production this is not what you want, so don't overlook this detail.

#### OpenShift/Kubernetes configuration

##### Deployment/DeploymentConfig

If using OpenShift it's recommended to use either a [Deployment](https://docs.openshift.com/container-platform/4.1/applications/deployments/what-deployments-are.html) or [DeploymentConfig](https://docs.openshift.com/container-platform/4.1/applications/deployments/what-deployments-are.html#deployments-and-deploymentconfigs_what-deployments-are) depending on what part of the [CAP theorem](https://en.wikipedia.org/wiki/CAP_theorem) you value more.

If you prefer consistency, go with a DeploymentConfig.  If you would take availability over consistency, go with a Deployment.

For this example, we will use a Deployment, with a [ConfigMap](https://docs.openshift.com/container-platform/3.11/dev_guide/configmaps.html) for certificates and a [Secret](https://docs.openshift.com/container-platform/3.7/dev_guide/secrets.html) for the private key:

```yaml
apiVersion: v1
kind: List
metadata: {}
items:
- apiVersion: apps/v1
  kind: Deployment
  metadata:
    labels:
      app: metals-example
    name: metals-example
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: metals-example
    template:
      metadata:
        labels:
          app: metals-example
      spec:
        containers:
        - image: quay.io/freedomben/metals-example:latest
          name: metals-example
          imagePullPolicy: Always
        - image: quay.io/freedomben/metals:latest
          name: metals
          imagePullPolicy: Always
          ports:
          - containerPort: 8443
            protocol: TCP
          envFrom:
          - configMapRef:
              name: metals-example-settings
          - secretRef:
              name: metals-example-private-key
- apiVersion: v1
  kind: ConfigMap
  metadata:
    labels:
      app: metals-example
    name: metals-example-settings
  data:
    METALS_SSL_CERTIFICATE: |
      -----BEGIN CERTIFICATE-----
      ...
      -----END CERTIFICATE-----
    METALS_SSL_CLIENT_CERTIFICATE: &rootca |
      -----BEGIN CERTIFICATE-----
      ...
      -----END CERTIFICATE-----
    METALS_SSL_TRUSTED_CERTIFICATE: *rootca
- apiVersion: v1
  kind: Secret
  metadata:
    labels:
      app: metals-example
    name: metals-example-private-key
  type: Opaque
  stringData:
    METALS_SSL_CERTIFICATE_KEY: |
      -----BEGIN RSA PRIVATE KEY-----
      ...
      -----END RSA PRIVATE KEY-----
```

##### OpenShift Service

If you are using MeTaLS then you will want a Service object to provide load balancing across your pods and to expose your application at a consistent IP address as pods go through the [Pod Lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/).

Your Service should point *only to the port that MeTaLS is servicing*, which is port 8443 (and 9443 for health checks).  Even though the application is listening on 8080, that is only for proxied requests by MeTaLS and should never be exposed outside the Pod.

```yaml
apiVersion: v1
kind: List
metadata: {}
items:
- apiVersion: v1
  kind: Service
  metadata:
    labels:
      app: metals-example
    name: metals-example
  spec:
    ports:
    - name: 8443-tcp
      port: 8443
      protocol: TCP
      targetPort: 8443
    selector:
      deployment: metals-example
```

##### OpenShift Route

If you want to expose your Service externally (outside of the OpenShift cluster), you will want to use an OpenShift [Route](https://docs.openshift.com/container-platform/3.9/dev_guide/routes.html).  If using Kubernetes, you will want to use an [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) that is supported by your platform.

Important note:  The [OpenShift route](https://docs.openshift.com/enterprise/3.0/architecture/core_concepts/routes.html#route-types) (or Ingress) *must* be configured for _*passthrough*_ encryption for this to work.

```yaml
- apiVersion: route.openshift.io/v1
  kind: Route
  metadata:
    labels:
      app: metals-example
    name: metals-example
  spec:
    port:
      targetPort: 8443-tcp
    to:
      kind: Service
      name: metals-example
      weight: 100
    wildcardPolicy: None
    tls:
      termination: passthrough
```

##### Outside health checks

If you need health checks that will come through the OpenShift Route (for example, if you are using an F5 GTM to load balance between clusters) you will need two Routes:

1. one for the application normal traffic
1. one for health checks.

This is because nginx must use two separate ports.  The client authentication happens as part of the TLS negotiation, which takes place before any path-based routing decisions can be made.  Therefore only port numbers can be used to differentiate requests that are intended for health checks vs. regular application requests.

Some of the YAML that hasn't changed from above is omitted to make it easier to read, but a full, deployable YAML example with health checks is available [here](https://github.com/FreedomBen/metals-example/blob/master/examples/metals-example-ocp-secrets-health-checks.yaml):

```yaml
apiVersion: v1
kind: List
metadata: {}
items:
- apiVersion: v1
  kind: Service
  metadata:
    labels:
      app: metals-example
    name: metals-example
  spec:
    ports:
    - name: 8443-tcp
      port: 8443
      protocol: TCP
      targetPort: 8443
    - name: 9443-tcp
      port: 9443
      protocol: TCP
      targetPort: 9443
    selector:
      deployment: metals-example
- apiVersion: route.openshift.io/v1
  kind: Route
  metadata:
    labels:
      app: metals-example
    name: metals-example-health-checks
  spec:
    port:
      targetPort: 9443-tcp
    to:
      kind: Service
      name: metals-example
      weight: 100
    wildcardPolicy: None
    tls:
      termination: passthrough
- apiVersion: route.openshift.io/v1
  kind: Route
  metadata:
    labels:
      app: metals-example
    name: metals-example
  spec:
    port:
      targetPort: 8443-tcp
    to:
      kind: Service
      name: metals-example
      weight: 100
    wildcardPolicy: None
    tls:
      termination: passthrough
- apiVersion: apps/v1
  kind: Deployment
  metadata:
    ...
  spec:
    ...
- apiVersion: v1
  kind: ConfigMap
  metadata:
    labels:
      app: metals-example
    name: metals-example-settings
  data:
    METALS_HEALTH_CHECK_PATH: "/health"  # This will bypass client auth in MeTaLS for /health
    METALS_SSL_CERTIFICATE: |
      ...
```

## FAQS

### 1. What format do certificates/keys need to be in for nginx to understand them?

Nginx only supports PEM, so this is the format all keys/certs are expected to be in.  There are numerous tools that can convert between format for you.  I typically use openssl, which could be used like this if you had a DER and needed a PEM:

```bash
openssl x509 -inform DER -in my-service-cert.der -outform PEM -out my-service-cert.pem
```

### 2. Why does this image use dumb-init?

Unfortunately nginx does not properly handle signals, which means without an init system it will not exit cleanly.  It can take many seconds to exit, which at best unnecessarily delays deployment roll outs, auto-scaling, and pod restarts, and at worst can leave zombie processes and other OS level garbage lying around.  The solution to this is an init system, and I chose dumb-init for it's signal rewriting, widespread usage in the community, and my past successful experience with it.

### 3. Why not use ubi-init?

This was my first preference but the image really isn't meant for this case.  It's intended for containers running multiple processes/apps.  It also includes full systemd which is way more bulk and attack surface than necessary.  If you would prefer ubi-init for support/compliance purposes, it will require minor refactoring of the Dockerfile but otherwise should work just fine.  I intend to provide this in the future if there is demand, so if you do it please contribute it back with a PR!

### 4. Why not use tini?

Docker loves tini and even integrated it into Docker v1.13 and later.  I have used and liked tini in the past.  The only reason I went with dumb-init is because tini does not support signal rewriting, which is important for nginx.

### 5.  Why in the world did you use Bash?

Classic software development story.  This project started out small, and Bash was the obvious choice.  As complexity steadily grew, at some point Bash was no longer the preferred language but schedules were tight, project managers were hounding, and porting was not an option.  Because there wasn't time in the schedule for automated tests, refactoring into a proper language is a risky (regression-wise) and time-consuming undertaking.

### 6.  Why the name MeTaLS?

The name MeTaLS is dual purpose.  It's what I hear when pronouncing the acronym MTLS, and it's also a hat tip to one of my favorite fiction book series of all time, [Mistborn](https://en.wikipedia.org/wiki/Mistborn).

### 7.  Which pre-built images are available?

Section moved to documentation above.  See [Pre-Built Images](#pre-built-images)

### 8.  Which version of nginx does this use?

You can take your pick.  The default version currently is 1.16 as that is the latest stable version.  Version 1.14 is also available and has received a lot of testing.  1.17 is being worked on.

If you prefer to use a [Red Hat based image (UBI)](https://www.redhat.com/en/blog/introducing-red-hat-universal-base-image) then go with 1.14.  1.16 is a Fedora based image.  1.17 is based on [the official debian-based nginx image available on Docker Hub](https://hub.docker.com/_/nginx).
