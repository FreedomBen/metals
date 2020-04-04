# Introducing Podman Pods to add mTLS

*Written by Benjamin Porter*

*Note:  I mention OpenShift here, but there is nothing unique to OpenShift discussed here that doesn't equally apply to Kubernetes.  If you aren't an OpenShift user, just `s/OpenShift/Kubernetes/g` and follow along!*

You've likely heard of OpenShift Pods and some of the neat features they enable (such as shared network space), but what you may not know is that you don't need full OpenShift to make use of Pods!

## Why use a Pod outside of OpenShift?

If you are running an application where each instance only has one process, then using Pods doesn't get you much.  However, sometimes non-trivial applications need multiple processes running.  Let me give an example.

If you run a simple website on the internet, chances are you want it to be publicly available.  Anybody can find it, and read it.  You often hope that your site will be indexed by search engines and made available to potential readers.

However, in a lot of enterprise environments and the (extremely fun) self-hosted community, services (HTTP servers for example) are not intended to be open to the world.  They should not be publicly accessible.  They are sometimes exposed to the internet, but only valid users should be allowed to make requests.

An easy way to accomplish this is to use a reverse proxy (such as Nginx) to do access control using a technique such as mTLS.  I go into [detail about mTLS in some previous posts](#TODO), so I will not repeat all that here.  If you would like to know more about it, I encourage you to check out those posts.

So now we have a reverse proxy (nginx) as well as our application server.  We now have multiple processes that make up our application, but unfortunately best practice is to only have one process per container!  So what are we to do right?

There's one additional problem we have.  If our application server is exposed to the world, anybody can make requests to it and bypass our mTLS reverse proxy client authentication layer.  That won't do!

This is where Pods can help out in a big way.  However, let's take a couple steps back and talk about what containers are and then pods.  If you are already familiar with containers or pods, feel free to skip those sections.

## What are containers?

- TODO: Not finished with this section

There are plenty of great descriptions about containers out there, and there are literally whole books written on the subject.  I will attempt to make a few important points, but for detailed understanding I will refer you to other resources.  Check out [this post at the Rising Stack blog](https://blog.risingstack.com/operating-system-containers-vs-application-containers/) for a good introduction.

At a high (slightly over-simplified) level, a container is like a mini operating system in which your program runs.  It has its own isolated space where it has access to everything it needs, but no more.  As far as the process is concerned, there is nothing else running on the "machine."

There are many different resources that an Operating System provides access and regulation to, such as a filesystem, a network interface, RAM (memory), etc.  These are things that the process in the container needs to get its job done.

A useful (though not perfect) analogy is a virtual machine.  A virtual machine allows different operating systems to share the same hardware, with a single OS in charge as the host.  A hypervisor (a program that emulates hardware) makes it appear that the guest OS has control of hardware.

The containerization technology (which is implemented in the host operating system kernel) is responsible for making this isolation happen.

There are numerous benefits of containers that make them highly desirable for us, such as security and portability.

## What are Pods?

- TODO: Not finished with this section

Simply put, Pods allow you to run multiple containers as a single unit of execution.  If you recall from the last section, while you *can* run multiple processes in one container, you shouldn't.  There are a variety of reasons why, but I won't go into them here.  
