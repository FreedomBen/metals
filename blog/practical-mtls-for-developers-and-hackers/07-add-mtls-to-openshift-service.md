# Adding mTLS to an HTTP service in OpenShift/Kubernetes

For our next example, we will take a web server written in Ruby that is already deployed to OpenShift, and add mTLS to it.

The source code for this sample app is available on the [metals-example github page](https://github.com/FreedomBen/metals-example).  If your OpenShift cluster can reach the internet, you can use the provided images from quay.io.  If not, you will need to build the image locally and put it somewhere that your OpenShift cluster can find. 

### What are the certs/keys used for?

Before we start looking at the YAML for this Deployment, let's talk about which certificates we have, what they are for, and how we will use them.  There are three certificates and keys in the example repository.  

* rootca.key - This is the private
#TODO

### Hacking some YAML

Let's first take a look at our existing Deployment. This includes an OpenShift `Service` and a `Route` to expose it:

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
    - name: 8080-tcp
      port: 8080
      protocol: TCP
      targetPort: 8080
    selector:
      deployment: metals-example
- apiVersion: route.openshift.io/v1
  kind: Route
  metadata:
    labels:
      app: metals-example
    name: metals-example
  spec:
    port:
      targetPort: 8080-tcp
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
          env:
          - name: APP_ROOT
            value: /opt/app-root
          - name: HOME
            value: /opt/app-root/src
          ports:
          - containerPort: 8080
            protocol: TCP
```

If you deploy this YAML to OpenShift, you should be able to `curl` the echo server through the OpenShift Route.  If my OpenShift route were at `tls-nginx-example.apps.cluster-1.example.com`, I would do this:  

```bash
$ curl "http://metals-example.apps.cluster-1.example.com/some/random/path"
127.0.0.1 GET /some/random/path - : {}
```

The response you see there is what the echo server echoed back to us.

To add mTLS to this deployment, all we need to do is add another container to the Pod definition, so let's go ahead and do that.  We will move the exposed port from 8080 on the metals-example container and put it on the metals at 8443.  Because the metals image takes quite a few environment variables, we will create a Secret and a ConfigMap elsewhere and automatically map the data from those into the container:

```yaml
      spec:
        containers:
        - image: quay.io/freedomben/metals-example:latest
          name: metals-example
          imagePullPolicy: Always
          env:
          - name: APP_ROOT
            value: /opt/app-root
          - name: HOME
            value: /opt/app-root/src
        - image: quay.io/freedomben/metals:latest
          name: mtls
          imagePullPolicy: Always
          ports:
          - containerPort: 8443
            protocol: TCP
          envFrom:
          - configMapRef:
              name: metals-example-settings
          - secretRef:
              name: metals-example-private-key
```

Now that we've added our container, we need to put our Secret key into a ConfigMap. To avoid a bunch of noisy lines, I have omitted some of the key here:

```yaml
- apiVersion: v1
  kind: Secret
  metadata:
    labels:
      app: metals-example
    name: metals-example-private-key
  type: Opaque
  stringData:
    # Private key for service
    METALS_PRIVATE_KEY: |
      -----BEGIN RSA PRIVATE KEY-----
      MIIJKQIBAAKCAgEAxYZUBrnPTzcnkKjg8bFtfW8lY2/xgiy9Mve0jjWEyhFPeITa
      gp5+yxdUaLJdWOMQ2qUn5LOOG20tB6L2cEXgQQEDZa0X8NbNAKI/JAhBUQUgIa/q
      ...
      Z/O9sk5fWOkr24uVhD5hVpjJ75JR3sEaxr6Ma0aB1+RKfI5Te9YCOakvQWCMqf2h
      kc5Lsq391FjEDox1TmHBLMA9BymQg9T75y3rUD/s99XJgv1e+osHrnECSZ2l
      -----END RSA PRIVATE KEY-----
```

Next let's create a ConfigMap with our other values in it.  We'll include the public certificates (which are not secrets), as well as the remaining environment variables that we need. Again I've truncated part of the certificates so that it is easier to see.  Because the server and client trust chains are the same (the root.ca in this case), I have used a [YAML DRY technique to reference an anchor](https://medium.com/@kinghuang/docker-compose-anchors-aliases-extensions-a1e4105d70bd):

```yaml
- apiVersion: v1
  kind: ConfigMap
  metadata:
    labels:
      app: metals-example
    name: metals-example-settings
  data:
    METALS_SSL: "on"
    METALS_SSL_VERIFY_CLIENT: "on"
    METALS_DEBUG: "true"
    METALS_FORWARD_PORT: "8080"
    METALS_PROXY_PASS_PROTOCOL: "http"
    METALS_PROXY_PASS_HOST: "127.0.0.1"
    METALS_PUBLIC_CERT: |
      -----BEGIN CERTIFICATE-----
      MIIJQDCCBSigAwIBAgICEAEwDQYJKoZIhvcNAQELBQAwVzELMAkGA1UEBhMCVVMx
      CzAJBgNVBAgMAklEMQ4wDAYDVQQHDAVCb2lzZTEXMBUGA1UECgwOQm9pc2UgQmFu
      ...
      LPXIhYWoMTYp/CB7+YQ4xIj8LQ79obmae2GrCpFkOzOhw+sjn2k7VEEW60ZvD56Z
      2cKquipmE7CU4f5Yj6eOgaML3k4=
      -----END CERTIFICATE-----
    METALS_CLIENT_TRUST_CHAIN: &rootca |
      -----BEGIN CERTIFICATE-----
      MIIJgTCCBWmgAwIBAgIJAI45yy3ikizxMA0GCSqGSIb3DQEBCwUAMFcxCzAJBgNV
      BAYTAlVTMQswCQYDVQQIDAJJRDEOMAwGA1UEBwwFQm9pc2UxFzAVBgNVBAoMDkJv
      ...
      xnFvoY0R3gx/AvDM0+MHUMgbDBSVXBx8vK9JhYIFI+0E301bRgo3IGKzZeLTdTT1
      XuV865TpREo5JquzQWxJtbyKxjJa5RY7f9kN5lRFpzteY560YA==
      -----END CERTIFICATE-----
    METALS_SERVER_TRUST_CHAIN: *rootca
```

Once all put together, our YAML file should look like this.  Yours may vary a bit if you built your own images or want to use Vault, or tweak other settings, etc.

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
          env:
          - name: APP_ROOT
            value: /opt/app-root
          - name: HOME
            value: /opt/app-root/src
        - image: quay.io/freedomben/metals:latest
          name: mtls
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
  kind: Secret
  metadata:
    labels:
      app: metals-example
    name: metals-example-private-key
  type: Opaque
  stringData:
    # Private key for service
    METALS_PRIVATE_KEY: |
      -----BEGIN RSA PRIVATE KEY-----
      MIIJKQIBAAKCAgEAxYZUBrnPTzcnkKjg8bFtfW8lY2/xgiy9Mve0jjWEyhFPeITa
      gp5+yxdUaLJdWOMQ2qUn5LOOG20tB6L2cEXgQQEDZa0X8NbNAKI/JAhBUQUgIa/q
      ...
      Z/O9sk5fWOkr24uVhD5hVpjJ75JR3sEaxr6Ma0aB1+RKfI5Te9YCOakvQWCMqf2h
      kc5Lsq391FjEDox1TmHBLMA9BymQg9T75y3rUD/s99XJgv1e+osHrnECSZ2l
      -----END RSA PRIVATE KEY-----
- apiVersion: v1
  kind: ConfigMap
  metadata:
    labels:
      app: metals-example
    name: metals-example-settings
  data:
    METALS_SSL: "on"
    METALS_SSL_VERIFY_CLIENT: "on"
    METALS_DEBUG: "true"
    METALS_FORWARD_PORT: "8080"
    METALS_PROXY_PASS_PROTOCOL: "http"
    METALS_PROXY_PASS_HOST: "127.0.0.1"
    METALS_PUBLIC_CERT: |
      -----BEGIN CERTIFICATE-----
      MIIJQDCCBSigAwIBAgICEAEwDQYJKoZIhvcNAQELBQAwVzELMAkGA1UEBhMCVVMx
      CzAJBgNVBAgMAklEMQ4wDAYDVQQHDAVCb2lzZTEXMBUGA1UECgwOQm9pc2UgQmFu
      ...
      LPXIhYWoMTYp/CB7+YQ4xIj8LQ79obmae2GrCpFkOzOhw+sjn2k7VEEW60ZvD56Z
      2cKquipmE7CU4f5Yj6eOgaML3k4=
      -----END CERTIFICATE-----
    METALS_CLIENT_TRUST_CHAIN: &rootca |
      -----BEGIN CERTIFICATE-----
      MIIJgTCCBWmgAwIBAgIJAI45yy3ikizxMA0GCSqGSIb3DQEBCwUAMFcxCzAJBgNV
      BAYTAlVTMQswCQYDVQQIDAJJRDEOMAwGA1UEBwwFQm9pc2UxFzAVBgNVBAoMDkJv
      ...
      xnFvoY0R3gx/AvDM0+MHUMgbDBSVXBx8vK9JhYIFI+0E301bRgo3IGKzZeLTdTT1
      XuV865TpREo5JquzQWxJtbyKxjJa5RY7f9kN5lRFpzteY560YA==
      -----END CERTIFICATE-----
    METALS_SERVER_TRUST_CHAIN: *rootca
```

NOTE:  The keys/certs are still truncated, so would not actually work if deployed like this.  If you want to actually deploy this, please use [this YAML from the OCP Secrets example](https://github.com/FreedomBen/metals-example/blob/master/examples/metals-example-ocp-secrets.yaml).

With the file created, let's go ahead and deploy it!  I will assume you are already authenticated.  Let's make a new project so we don't clash with anything else:

```bash
$ oc new-project metals-example
Now using project "metals-example" on server "<clipped>".

You can add applications to this project with the 'new-app' command. For example, try:

    oc new-app django-psql-example

to build a new example application in Python. Or use kubectl to deploy a simple Kubernetes application:

    kubectl create deployment hello-node --image=gcr.io/hello-minikube-zero-install/hello-node
```

If you put the YAML in a file called `examples/metals-example-ocp-secrets.yaml`, then you can deploy it with:

```bash
$ oc apply -f examples/metals-example-ocp-secrets.yaml
service/metals-example created
route.route.openshift.io/metals-example created
deployment.apps/metals-example created
configmap/metals-example-settings created
secret/metals-example-private-key configured
```

To clean up, or if you want to delete it all, you can use the label we assigned in the YAML:

```bash
oc delete all -lapp=metals-example
```  

Let's makes sure our Pod is up and is healthy:

```bash
$ oc get pods
NAME                                  READY   STATUS    RESTARTS   AGE
metals-example-59469f4c9f-fqbfc   2/2     Running   0          94s
```

Make sure your Route is created and ready:

```bash
$ oc get route
NAME            HOST/PORT                                 PATH    SERVICES        PORT       TERMINATION   WILDCARD
metals-example   metals-example.apps.cluster-1.example.com          metals-example   8443-tcp   passthrough   None
```

Great, let's curl it!

```bash
curl "http://metals-example.apps.cluster-1.example.com/some/random/path"
```

# TODO curl -v
