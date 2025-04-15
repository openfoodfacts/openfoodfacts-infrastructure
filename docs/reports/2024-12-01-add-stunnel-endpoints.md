# 2024-12-01 Add stunnel endpoints

On OVH1 reverse proxy, I (Raphaël) added 2 new stunnel endpoints, to access Triton running on `moji-docker-prod-2`.

The reason why we used the stunnel running on the OVH1 reverse proxy is that it's the only CT that has an ipv6 address (which is necessary to reach the moji server).

I deployed 2 endpoints, one for HTTP access (port 5503) and on for gRPC access (port 5504).

For the 2 endpoints, the `accept` parameter was set to the `10.1.0.101` IP address (the IP address of the reverse proxy CT), preventing the two services from being accessed from the outside.

I checked that's the case by checking that the port was indeed not accessible from the outside.