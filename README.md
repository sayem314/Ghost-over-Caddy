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

*This script is based on Lin Song [Nginx version](https://github.com/hwdsl2/setup-ghost-blog)*
