---
name: VM template
about: Ask for a VM on OFF infra.
title: ''
labels: container
assignees: cquest

---

[All the following limits (RAM, CPU, storage) can be dynamically adjusted later.]

### OS
[What OS do you want? Default to Debian last Stable.]

### Local disk space
[Explain if > 32 Gb.]

### Shared disk space
[Explain if > 1 Tb.]

### RAM
[Explain if > 4 Gb.]

### Nb of CPU
[Explain if > 4.]

### Main software bricks
[This is just for information. The machine is provided bare. Example: PostgreSQL, Node.js, Apache, etc.]

### Reverse proxy
[On OFF infra all web services use a reverse proxy. Do you need it? What's the name of the service (FQDN, eg. myservice.openfoodfacts.org). Note: port 443 default for extern entries (reverse proxy) and 80 for intern (your machine).]

### Usage
[One or two lines.]

### Machine administrators
[Default: you. Please indicate your github account name to retrieve your SSH key. Prefer your SSH key published on Github, eg. https://github.com/CharlesNepote.keys 
There should be a main administrator and a co-administrator.]
