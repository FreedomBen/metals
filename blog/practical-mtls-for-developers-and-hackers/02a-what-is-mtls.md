# What is Asymmetric Encryption?

*Written by:  Benjamin Porter*

Why you should care:
* You can't understand the language of SSL/TLS/mTLS without the language of asymmetric encryption
* It's hard to add SSL/TLS/mTLS to your app if you don't understand the language
* You need SSL/TLS/mTLS on your website/app if only for the improved SEO and to protect your users' privacy

Asymmetric encryption is one of those things that you use hundreds of times a day, but rarely if ever notice it.  The ideas behind it are in widespread use, but most of the time you don't need to understand it to benefit from it.

If you work in web development or operations however, adding SSL/TLS/mTLS to a web service may be something you are asked to do.  Many guides will help you to understand the steps to implement that, but they assume you have a familiarity with asymmetric encryption already.  This blog post aims to provide you with that background (a future post of mine will expand on this to explain TLS as well).

Speaking the language of mTLS is something developers have largely not had to do, but as we increasingly move toward Platforms as a Service and DevOps, more of the burden for configuring mTLS is falling on developers.  It is worth investing some time now to understand the theoretical foundation.  It will help you a lot with learning the language of X.509.

With that sales pitch out of the way, let's talk about encryption!

## A quick overview of Symmetric Encryption

Before we dive straight to asymmetric encryption, it's helpful to understand the alternative (which is conceptually a lot simpler and easier to grasp):  symmetric encryption.

Broadly speaking, encryption comes in two flavors:  Symmetric and Asymmetric.  Symmetric is what you think of most often, where the same key (or password) is used to both encrypt and decrypt the data.

The most popular symmetric encryption algorithm is [Advanced Encryption Standard (AES)](https://en.wikipedia.org/wiki/Advanced_Encryption_Standard), used nearly everywhere.  Symmetric encryption (and AES specifically) is great because it can be done rather easily in hardware and is very simple to understand.  If you have the key, you have the data, and performance is great thanks to the widely available hardware implementations.

## Examining Symmetric Encryption's largest flaw

However, symmetric encryption is not all roses.  It suffers from a problem:  all parties to the conversation need to know the key, and the key can't be encrypted.

Exchanging the shared key in a secure way can be difficult and totally impractical.  It may be worth thinking about the problem for a minute.  If you have a key/password that you want to share with someone, how do you send it to them?  Can you tell them over the phone?  What if this person is a stranger whose phone number you don't have?  What if it's not a human at all, and is rather a machine?

Exploring the problem more, you can't encrypt the key with itself because the receiver doesn't have it yet.  What we have here, is a [chicken or the egg](https://en.wikipedia.org/wiki/Chicken_or_the_egg) problem!  You could try sending the key through a different medium (like the phone, or a different email account), but that runs the risk that [Eve](https://en.wikipedia.org/wiki/Alice_and_Bob) may be listening on that medium as well, and could intercept your key and gain access to the data!  We have a non-trivial problem here.

## Asymmetric Encryption can solve this problem!

Asymmetric encryption is here to help!  With asymmetric encryption, rather than using a single key to both encrypt and decrypt the data, each party to the conversation has two keys: a private and a public key.

In line with their names, the private key is always kept a secret from everyone except its owner.  In fact, ideally it should be generated on and _never_ transmitted off of the device on which it is needed.  In the real world sometimes it is necessary to move it, but proper precautions should be taken to protect the private key in transit as if it is compromised then Eve can decrypt everything.

The public key is the exact opposite:  It is published as widely as possible.  These two keys are related mathematically such that they undo each other (inverse operations).  If you encrypt with the public key, only the private key can decrypt it, and vice versa.  Without knowing both keys, you can only do one-way encryption.

I'm not going to go into depth on the math here since knowing the relationship is the important part, but if you have a hunger for this, see the section "How does RSA encryption work?" on [What is RSA encryption and how does it work?](https://www.comparitech.com/blog/information-security/rsa-encryption/).

But to conceptually grasp it, think of it this way.  When you were learning exponents, it was easy to calculate the result of a number raised to an exponent, even when large.  However, calculating the root was _not_ easy.  Even just squares and square roots can demonstrate this.  14641^2 is easy to calculate (with a computer).  It is 214358881.  However, finding the square root of 214358881 is really difficult, even for a computer.

With RSA (the most popular asymmetric encryption algorithm) it isn't exponents, but rather very very large prime numbers.  However the concept is the same.  Trying to figure out which prime numbers were used to calculate a value is really difficult (even for a computer) when their values are not known.

## Anyway, back to how asymmetric helps with our symmetric problem

This is great because we now have a solution for exchanging our symmetric key!  If Alice wants to send Bob a message, she can encrypt the message with Bob's _public key_ (which is widely available).  Now, only *Bob* can decrypt this message, because only he has his private key.  If the message is intercepted by Eve, she will just see what appears to be random noise.  If she attempts to running it through the public key it will just yield gibberish.  Perfect!

We now have achieved an important goal of encryption:  confidentiality (or secrecy).  But, let's think a little more about the interesting relationship between these two mathematically-related keys.  Knowing that they are inverse operations (effectively undoing the effects of each other), it seems like we can take this a step further and achieve another important goals.
<here>

To understand our second goal, let's ask ourselves a question:  How does Bob know that Alice is the one who sent the message, and not Eve playing a trick on him?  Suppose Eve intercepted Alice's message.  Eve could not decrypt it so does not know what its contents are.  However, she knows she doesn't want *Bob* to get it either.  Eve silently replaces Alice's message with one of her own.

With our current system, Bob can not verify that Alice is indeed the sender.  Depending on the importance of the data, this could be a huge problem, potentially much bigger than if the data were inadvertently disclosed!

Because we know the mathematical relationship between the public/private key pairs, there is actually a handy solution here hiding in plain sight!  

If Alice and Bob both have a message they know about, Alice can encrypt it using her *private* key.  Bob (or anyone else in the world) can then *decrypt* this message with Alice's *public* key, verify that it decrypts to the known value, and then be confident that only Alice could have encrypted the message in the first place because only Alice has the private key required to encrypt that message for which the public key would successfully decrypt!

This is called *message signing*, and it achieves for us another important goal.  We know that Alice really did originate this message.

Because we know the value that part of the message should decrypt to, we can also verify message integrity.  If somebody changes the message, it will no longer decrypt properly with Alice's public key.  If this happened, we would know that somebody tampered with it in transit (and who else but Eve would do such an evil thing!?).

We now have a pretty valuable communication tool now!  By combining the two capabilities of asymmetric encryption, we can both hide the contents of a message and also ensure the identity of the senders at the same time.  Neato!

You are now ready to learn about TLS!
