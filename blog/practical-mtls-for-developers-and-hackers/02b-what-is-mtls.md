# What is mTLS and How Does it Work?

## Part 2 - TLS and mTLS

*Written by:  Benjamin Porter*

## What is TLS?

Before reaching our goal of understanding mTLS you need to understand TLS.  There are tons of resources out there that vary in technical depth.  My goal here is familiarization, not mastering (which requires complex understanding of cryptography and various standards like [X.509](https://en.wikipedia.org/wiki/X.509).

You have already used TLS hundreds of times today.  Any websites you visit with `https` as the protocol, is making use of TLS.  The server has used [asymmetric encryption](#TODO) to encrypt your requests (providing confidentiality) and has also proven it's identity to you, so you know that it was actually Google who answered your request on https://www.google.com, and not your malicious hacker neighbor who likes to hack you.

Before we proceed further, let's briefly talk about SSL and how it relates to TLS (the two are often confused).  SSL was the *predecessor* of TLS and is deprecated.  However you will sometimes see SSL and TLS used interchangeably where technical precision is paramount, or to support legacy implementations (for example Nginx variables often include "ssl" in their name, even though it's actually TLS being worked on).  #TODO - more explanation and possibly move to different section?

## How does TLS verify identities?

Since we are primarily interested in the identity verification portion of TLS for this blog post, let's talk about how TLS currently does identity verification.

When setting up a server, you need to generate a public/private key pair to use with asymmetric encryption.  The terms often used are "key" and "certificate" but the concept is the same.  The "key" is a private encryption key, and the "certificate" is a public key that you will share with the world.  When the server presents the certificate to the client, it is challenged and proves that it owns the private key that corresponds to that public certificate.  This way we know that we are really talking to the owner of the presented certificate.  We now have our basic building blocks!

But wait!  How can you trust that the person isn't lying about their identity!  For example, what stops Eve from generating a private/public keypair and claiming to be Google.com on her certificate?  She has the corresponding private key so we now she really does own that certificate.  However, there is nothing to prevent her from filling that certificate with lies about her identity!

This is where Chains of Trust or Trust Chains come in.  This is often the most confusing aspect so try to bear with me.  In order to know if Alice can trust Bob, we need to find a trusted third party to vouch for Bob (somebody who both Alice and Bob mutually trust).  If my friend Steve is trusted by Alice and Bob, and he tells Alice that Bob's certificate is valid, then she knows that his certificate isn't filled with lies (and if it is, then Steve is untrustworthy too).  In this scenario, Steve is acting as a Certificate Authority.

A [Certificate Authority](https://en.wikipedia.org/wiki/Certificate_authority) is a trusted third party that can "sign" certificates adding their stamp of approval.  This allows the verifier to know that they mutually trust somebody.  A signature is done by using the private key to encrypt a known secret and adding it to the certificate.  A verifier can then use the signer's public certificate to decrypt the value, thus proving that only the owner of the signer's private key could have signed it.

There are often several layers of certificate authorities, for various reasons. Let's go back to our scenario.  Steve has generated public/private key pairs for himself so that he can sign certificates for people.  He is hoping to turn this into a successful business, but that means that if large swaths of people automatically trust his signature, then his private keys become *extremely* valuable.  If Eve is able to compromise them, she can create her own bogus certificates with any name she likes and give it the legitimacy of Steve.

Because of this risk, Steve decided to keep his private key extra super duper secure by locking it into a safe.  However, as he gets more and more business it isn't scalable to pull it out every time he needs to sign.  So, he creates a few additional certificate authorities that are signed by his original certificate authority.  The original is now the "root" CA and the others are "intermediate CAs."  This way Steve can distribute his root public key widely, but do the signing using the less juicy intermediate CA private keys.  This also makes it so that if one of the intermediate CA private keys is compromised, they can be revoked and recreated without requiring him to redistribute his public key all over, which would be extremely difficult to do (it is baked into most operating systems and browsers, so hard to change).

In real life, Steve would be a trusted root CA such as GlobalSign.  In fact, if you want you can see exactly how these public keys/certificates get bundled into Android by looking [at the source files](https://android.googlesource.com/platform/system/ca-certificates/+/master/files/).  Try clicking on a certificate and reviewing the information that is in there.  If you are a Windows user, you may be interested in reviewing [Microsoft's trust root](https://docs.microsoft.com/en-us/security/trusted-root/participants-list).

When a client connects to a server using TLS, the server will send it's certificate to the client, and the client can then walk the trust chain (follow each certificate signer) until arriving at one that is already trusted.  If this happens, and the server hostname matches the one the client connected to, identity is proven.

## What is the "m" in "mTLS?"

In the previous scenario, notice that while you were able to verify the identity of Google.com, Google was not able to verify *your* identity (ok, they likely know it's you because you are logged in to your google account and thus submitted identifying cookies and such, but let's pretend that nothing like that is available to them).

Sometimes, especially in enterprise environments, we don't want just *anybody* to call our service.  If we are writing a backend service that is part of a [Service Oriented Architecture (SoA)](https://en.wikipedia.org/wiki/Service-oriented_architecture) for example, it may only be valid for one particular service to call us, and never the end user.  In this case, we may want to verify the client's identity before allowing them to make HTTP requests to us.

This brings us to the "m" in "mTLS."  The "m" stands for "mutual," which means, the client and server each verify each other's identities before proceeding on to the HTTP transaction.  There are no limitations here other than that the client must have (and submit) a certificate signed by a CA that the server recognizes.  In enterprise environment this is often a company internal CA, though it does not have to be.

Perhaps I can use an example from my real life where I used mTLS.  I created an instance of [Password Maker](https://passwordmaker.org/passwordmaker.html) for myself, but I changed several of the defaults to make configuring it easier and so that I had less variance to remember.  I also added some functionality that would make it easier for an attacker to guess my passwords.  This was awesome for user experience, but bad for security.  

Since I was the *the only valid user*, I wanted a way to expose it to the internet at large (so I could get to it anywhere I happened to be) but the site is a simple HTML page with no backend to do access control.  Never fear!  mTLS was exactly what I needed!

I generated my own root CA, and minted a client cert and a server cert, and configured my nginx web server (serving the HTML page from my Digital Ocean droplet) to require client authentication prior to serving the page.  I then put my client key/cert on my laptop and android phone, and boom.  I had a very secure setup such that nobody except myself could view my Password Maker HTML page.  Then my wife wanted access!

Not a problem!  I minted her some client certs with my root CA, and with no changes at all on the server (because it already trusted my root CA) my wife now had access.  That server stayed up for years before I finally had no choice but to go with a more fully featured product.

## Great, how do I add mTLS to my service?

An excellent question good sir or madam!  There are nearly infinite possible answers to this question, and some are more ideal than others depending on your current software stack.  If you use Spring Boot for example, mTLS is essentially built in if you configure it.  If you just serve static assets like in my Password Maker example however, it is not.

Because of this variation, I settled on one solution that fits nearly all of my use cases.  Nginx is fully capable of doing mTLS.  It is battle tested by hundreds of thousands of sites (maybe millions or tens of millions, but I'm too lazy to look up statistics on it), and it functions very well as both a static asset server and also as a reverse proxy.  Perfect!  That matches basically every use case I have.  If using static assets nginx will serve them directly.  If running an application server using [Sinatra](http://sinatrarb.com/) or something, I'll use reverse proxy mode.

I use a project that I started years ago and recently revived, called [MeTaLS](#TODO).  I will be writing posts to walk through setting it up, but in the mean time feel free to review the [MeTaLS project docs](#TODO) and/or the [MeTaLS Example project](#TODO). 





The next few posts in this series will walk you through adding mTLS to:

1.  Generate some certificates
1.  A static website (The Password Maker from above) being served by Nginx (in an OCI/Docker image)
1.  A simple HTTP server deployed to a single VM, with nginx and the app server in a Pod with Podman
1.  A simple HTTP server deployed in a pod on OpenShift/Kubernetes

Buckle up!
