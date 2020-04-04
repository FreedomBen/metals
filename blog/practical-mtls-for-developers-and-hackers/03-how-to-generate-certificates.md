# How to Generate TLS/mTLS Certificates

As we generate things, I'll give a brief explanation about what it is that we are doing.  However, if you don't already have a basic understanding of mTLS, you may want to read the previous post on what TLS/mTLS is and the basics of how it works (asymmetric encryption).  Otherwise, read on!

## A brief intro to OpenSSL

[OpenSSL](https://www.openssl.org/) is a robust, commercial-grade, and full-featured toolkit for the Transport Layer Security (TLS) and Secure Sockets Layer (SSL) protocols. It is also a general-purpose cryptography library. 

For our purposes, we are going to use OpenSSL to generate private keys, certificates, and [certificate signing requests (CSR)](https://en.wikipedia.org/wiki/Certificate_signing_request).

There are a lot of different ways to do the same thing in OpenSSL.  What you see here is just one example.  Often times you will see one command that generates keys and self signs a cert all in one go.  Since our purpose here is instruction and understanding, I have opted to split the generation of each artifact into one command.  This makes it easier to see what is really happening, so that you can better understand the process going on under the hood (which will greatly improve your ability to debug when things go wrong, which they will).

We are going to be generating a number of files.  To keep them organized, let's create a directory in which we can work:

```bash
mkdir arachne-certs
cd arachne-certs/
```

## Generate a self-signed Root CA

### Create config file for our Root CA

OpenSSL uses a config file for much of the configuration parameters.  There are lots of ways to dynamically feed the configuration in, and that is very useful for scripting.  However since we are trying to understand how to use OpenSSL in addition to simply getting what we need out of it, we will use a config file.

Create a file called `ca.conf` in the current directory.  For our purposes



### Private key for Root CA

Before we can issue certificates, we need to create a [Certificate Authority (CA)](https://en.wikipedia.org/wiki/Certificate_authority).  A CA will allow us to "sign" certificates, which is a way we can endorse a certificate as being trustworthy.  For purposes of example, let's assume we are the IT department for a company called Arachne Industries.  We have a number of employees and services that we support so we will be issuing certificates.

Let's create a root CA that we can use for signing certificates.  To begin, our Root CA will need a private key that can be used to prove that we are the legitminate CA.  This works using the principles of asymettric encryption (see [the previous post for more information](#TODO)).  We will use a key length of 8192.  You'll find debates about proper key length, but I don't want to get into that here:

```bash
openssl genrsa -out rootca.key 8192
```

After running this command, you will see a new file called `rootca.key` .  Open it up and take a look!  It should look something like this.  My file was nearly 100 lines long so I've omitted a lot from the middle:

```
-----BEGIN RSA PRIVATE KEY-----
MIISKQIBAAKCBAEAt5qnGXrN31DML4b2MoRCpqrZWvyUo1IPoznBwFbQTpSAPsrX
8SApQNOU0fE4Mq+r/2fOo1vasYEO8mAxxzAHJjoHdPenPLkxdyidDkrLodKoLyJv
...
OtNJ6qXoLl0ckUkozw3/qvf88KR39SEL1Y9i1ilBYHGopqDDRYJ+0Iw+zdFYvA95
cshwT6PUjLUgXOQefHqZJMEQ18i9HKNzGwGX3wY+3uhMM/sao16oHuUvCVhb
-----END RSA PRIVATE KEY-----
```

This format is called [PEM](https://en.wikipedia.org/wiki/Privacy-Enhanced_Mail).  It stands for "Privacy Enhanced Mail" for historical reasons, but don't let that confuse you.  The big takeaway is that this format is representable in only [ASCII](https://en.wikipedia.org/wiki/ASCII) characters which makes it easy to send through systems that can't handle binary data.

You may also see the term [DER](https://en.wikipedia.org/wiki/X.690#DER_encoding) used.  This is simple a different way to represent the same data.  For our purposes today however, we will only be using the PEM format.

### Public Certificate for Root CA

Now that we have a private key, we can create a public certificate.  This can be given out freely to anyone looking to verify our identity.  We will encode some properties into the certificate that can be read by other entities.  Again, for more information about how this works, see [the previous post](#TODO)

Using the private key, we can now generate a public certificate:

```bash
openssl req -new -x509 -days 1826 -key rootca.key -out rootca.crt -subj '/CN=localhost/O=Arachne/C=US/ST=ID'
```



## Generate an intermediate CA

## Generate a server key and certificate

## Generate a client key and certificate
