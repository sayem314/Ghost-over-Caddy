## Ghost-over-Caddy
Scripts to install your own Ghost blog on Ubuntu, Debian or CentOS, with Caddy (as a reverse proxy).

Powered by Node.js, Ghost blog is a simple and modern WordPress alternative which puts the excitement back into blogging. It's beautifully designed, easy to use, completely open source, and free for everyone.

### Requirements
A dedicated server or Virtual Private Server (VPS), freshly installed with:
* Ubuntu 16.04 (Xenial), 14.04 (Trusty) or 12.04 (Precise)
* Debian 8 (Jessie)
* CentOS 6 or 7
Note: A minimum of 512 MB RAM is required.

### Installation
First, update your system with apt-get update && apt-get upgrade and reboot. This is optional, but recommended.

`wget https://git.io/setup-ghost.sh`

`bash setup-ghost.sh BLOG_FULL_DOMAIN_NAME`

Note: Replace BLOG_FULL_DOMAIN_NAME above with your actual full domain name. The latest v0.11-LTS version of Ghost blog will be automatically installed.

#### CDN Users
Unfortunately if you're on CDN then Caddy can't obtain cert for you. You have to do some work, see DNS Challenge on [here](https://caddyserver.com/docs/automatic-https)

alternatively you can turn off tls. edit Caddyfile located on /etc/Caddyfile and remove email after tls and add word off

##### Donations
If you want to show your appreciation, you can donate via Bitcoin. Thanks!
1GN7M2W4eAXTLDCeskwsgqJB9gFA3gLqPB

*This script is based on Lin Song [Nginx version](https://github.com/hwdsl2/setup-ghost-blog)*
