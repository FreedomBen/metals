# Practical mTLS for developers and hackers

*Written by:  Benjamin Porter*

Some time ago as a developers/ops guy (at startups I wore a lot of hats) I was suddenly thrust into the world of mTLS.  It was a painful period, learning many, many concepts all at once.  There is plenty of information around the web, but it's not well organized and it's hard to know what you don't know.

My hope with this series is that you will come away very comfortable with the high level concepts of mTLS, as well as the ability to add mTLS to an existing service.

These posts are intended to be read in order for the most part, but if you are already comfortable with a concept feel free to skip that section.  I've attempted to write the series in a way that individual parts can stand alone for quick answers to specific questions, or be read together for a solid introduction to the subject.

If you do not need the client authentication portion of mTLS (meaning you just need regular TLS) this series will still be very helpful for you.  You simply don't need to bother with the client portions.

## Table of Contents:

1.  What is mTLS, and how does it work?
1.  How do I generate X.509 certificates for use with TLS/mTLS?
1.  How do I add mTLS to my existing nginx service?
1.  Introduction to Podman Pods
1.  Adding mTLS to simple server with Podman Pods
1.  How do I add mTLS to my existing OpenShift service?
