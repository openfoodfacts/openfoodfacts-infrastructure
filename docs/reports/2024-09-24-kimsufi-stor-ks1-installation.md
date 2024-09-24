# Kimsufi STOR - ks1 installation

## Rationale for new server

We have performance issues on off1 and off2 that are becoming unbearable, in particular disk usage on off2 is so high that 60% of processes are in iowait state.

We just moved today (24/09/2024) images serving from off2 to off1, but that just move the problem to off1.

We are thus installing a new cheap Kimsufi server to see if we can move the serving of images to it.

## Server specs

KS-STOR - Intel Xeon-D 1521 - 4 c / 8 t - 16 Gb RAM - 4x 6 Tb HDD + 500 Gb SSD

## Install

On OVH console, we install Debian 12 Bookworm on the SSD.

Once the install is complete, OVH sends the credentials by email.

We add users for the admin(s) and give sudo access:

sudo usermod -aG sudo [username]


