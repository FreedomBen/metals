# Adding mTLS to a Podman Pod

In the [previous post](#TODO) I talked about what Podman Pods are and why you would want to use them, but if you are anything like me there's nothing like a concrete example to clear up an abstract concept.

- TODO: rewrite this to flow better for this post

So, let's do a real example!  These days I ship *everything* in [pods](https://kubernetes.io/docs/concepts/workloads/pods/pod/).  Pods are a fancy idea that allows you to easily run multiple containers together.  An explanation of Pods is outside the scope of this article so I will assume familiarity with them.  If you are not familiar with Pods however, you should read about them.  The [Podman article on pods](https://developers.redhat.com/blog/2019/01/15/podman-managing-containers-pods/) is a good one to read.  To run pods on my local machine, I'll be using [podman](https://podman.io).  To run them remotely I'll be using [OpenShift](https://openshift.com).  Nothing here is special to OpenShift so should run fine on any OCI compliant Kubernetes distribution.  That said, I have not tested it outside of OpenShift.

For the [first example](#first-example) I will make use of Podman to run pods on my local machine.  We will get our application running locally.  If your runtime needs are limited to a single machine, you could even use this in production in lieu of a full OpenShift cluster.  When you are ready to scale horizontally it won't be difficult to move to full OpenShift because [Podman read/writes Kubernetes compliant Pod specs](https://developers.redhat.com/blog/2019/01/29/podman-kubernetes-yaml/).

For the [second example](#second-example), I will take an OpenShift deployment that already exists and add mTLS to it.  If you already have a Deployment that needs mTLS, you may want to follow along at home!

## First example

Our first example will be serving a static file behind access control.  I mentioned Password Maker earlier, and now we're going to deploy it!  If this were for real I would use only one instance of Nginx and have it serve static assets directly.  However, for purposes of demontrating the [metals](https://github.com/FreedomBen/metals) project, I will use metals as a reverse proxy in front of an Nginx image that serves the static assets over HTTP/port 80.

Our app diagram will look like this:

```
             +-----------------+
             | Client requests |
             +------+---^------+
                    |   |
                    |   |
                    |   |
                    |   |
                    |   |        Our Pod
          +---------|---|--------------------------------+
          |  +------v---+------      +----------------+  |
          |  |                |      |                |  |
          |  |     metals      |      | passwordmaker  |  |
          |  |                +------>                |  |
          |  |   exposed on   |      | in nginx       |  |
          |  |   pod  :8443   <------+                |  |
          |  |                |      | Listening on   |  |
          |  |                |      | localhost:80   |  |
          |  +-----------------      +----------------+  |
          +----------------------------------------------+
```

I have already containerized passwordmaker and pushed it up to [quay.io/freedomben/passwordmaker](https://quay.io/repository/freedomben/passwordmaker).  For convenicne there is a mirror on Docker Hub at [docker.io/freedomben/passwordmaker](https://hub.docker.com/repository/docker/freedomben/passwordmaker).  If you would like to examine [the source, it is on github](https://github.com/FreedomBen/passwordmaker).  For purposes of this tutorial, I will assume you are using the pre-built images.


In many of these examples I prefer the long form of options, which I find helps people not familiar with the command line switches to infer what they mean.  For example `--detach` is a lot clearer than `-d` for someone who isn't already familiar with `-d`.  When running these yourself you are of course welcome to use the short options.

### Step 1:  Get it running locally

Let's start by running/testing our server image.  It's nice to make sure it is working first, that way as we add to the pod we can be more confident that the new surface area contains any issues we may encounter.

Start by running the passwordmaker container locally:

```bash
podman run \
  -it \
  --rm \
  --publish 8080:8080
  --name 'passwordmaker'
  quay.io/freedomben/passwordmaker:2.5
```

You should now be able to browse to it by typing `http://localhost:8080` into your browser.

Great!  It works!  Terminate the container with Ctrl^c if you ran it in the foreground like I did, or use podman if you did not:

```bash
podman stop passwordmaker && podman rm passwordmaker
```


### Step 2:  Add our metals image in plaintext mode and make sure it works

We are now ready to add our metals image into the mix!  First let's create a podman pod. We'll expose 8080 for testing, but for production we would absolutely not want to expose it (because then people could go around our proxy)!:

```bash
export PODNAME=passwordmaker-pod

podman pod create \
  --name "${PODNAME}" \
  --publish 8080:8080 \
  --publish 8443:8443
```

We now have a pod, but nothing in it yet!  Actually that's not entirely true.  Podman create a container for k8s.gcr.io/pause that will hold our pod open, but don't worry about that.

Let's add our passwordmaker container from before to our new pod.  The command will be slightly different since we need to specify a pod to place it, and we no longer publish the port directly on the container itself (since it is exposed by the pod).  Also note that we assume the pod name is still in the environment variable `PODNAME`:

```bash
podman run \
  --detach \
  --name passwordmaker \
  --pod "${PODNAME}" \
  quay.io/freedomben/passwordmaker:2.5
```

You can now check that the image is running properly in the pod.  If you exposed port 8080 earlier you can hit refresh on your browser for `http://localhost:8080`.  You can also list running containers in podman:

```bash
podman ps --all --pod
```

We're ready to add metals!  All of the configuration for metals comes through environment variables.  Because of this there are a number of variables we need to set.  We don't have values for them yet, so we'll leave them blank.  We want to start mtls in plain text mode currently for testing (and because we don't have certificates yet!).

```bash
podman run \
  --detach \
  \
  --env METALS_TLS_ENABLED=off \
  --env METALS_TLS_VERIFY_CLIENT=off \
  --env METALS_DEBUG=true \
  \
  --env METALS_PROXY_PASS_PROTOCOL=http \
  --env METALS_PROXY_PASS_HOST=127.0.0.1 \
  --env METALS_FORWARD_PORT=8080 \
  \
  --env METALS_PUBLIC_CERT="<stub>" \
  --env METALS_PRIVATE_KEY="<stub>" \
  --env METALS_SERVER_TRUST_CHAIN="<stub>" \
  --env METALS_CLIENT_TRUST_CHAIN="<stub>" \
  \
  --name metals \
  --pod "${PODNAME}" \
  quay.io/freedomben/metals:latest
```

The full documentation for what all the variables are for is available on the [metals project documentation](https://github.com/FreedomBen/metals/blob/master/README.md#variables-1), but briefly the first two disable TLS so we can test in plaintext mode without certificates.  The proxy pass tell nginx how to find our backend service.  Since it is running int he same pod with our metals container, they share a network namespace, meaning it can be found at `localhost:8080` from the mtls container's perspective.  We're also using http between the mtls container and our backend server.  The "METALS_DEBUG" variable will enable verbose logging, which is useful when debugging.  If you're really stuck you can also set `METALS_TRACE=yes` but it is a firehose (and can print secrets to logs, so don't use in production!.  The last four variables provide nginx with our certificates.  Since we don't have them yet we'll just put `<stub>` in there.  We can't leave them blank because validation will fail.

Ok, is it running?

```bash
podman ps --all --pod
```

If the container is not running, you can take a look at the logs with:

```bash
podman logs metals
```

Before starting a new container, you will have to delete the old one when you no longer need the logs:

```bash
podman rm metals
```

Got any issues cleared out?  Great!  Fire up your browser but this time go to `http://localhost:8443`.  You should get our page, served through our proxy!  Note it is `http` so not yet secured with mTLS, but we're ready to proceed now.

### Step 3:  Add certificates

Generating certificates is somewhat out of scope for this blog post, but there are numerous online guides to help you.  I have written a post [here](#TODO) that you can read, and I also like [Raymii.org's OpenSSL tutorial](https://raymii.org/s/tutorials/OpenSSL_command_line_Root_and_Intermediate_CA_including_OCSP_CRL%20and_revocation.html), but there are plenty of good tutorials you can search for.

Because generating certificates is out of scope, I will direct you to the [test certificates that are part of the official example project](https://github.com/FreedomBen/metals-example/tree/master/certs/simple-root-client-server).  I will assume you will download and use the certificates from that repository.  However, if generating your own certs, the steps to install them should be the same.

*NOTE:  If you want to expose an OpenShift route in Passthrough mode with this, your OpenShift Route must be in one of the subjectAltNames of your certificate, otherwise clients will not recognize it*


NOTE:  The blog post is not yet finished here!  #TODO


