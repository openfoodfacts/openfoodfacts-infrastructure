# Stunnel

Stunnel enables us to secure (TCP) connection between distant servers.

It encrypts traffic with openssl.

It is installed on the reverse proxy of off2 and ovh1.

Illustration:
```mermaid
sequenceDiagram
    box  Network 1
      Participant Cli as Client
      Participant Scli as Stunnel Server 1 (client)
    End
    box Network 2
      Participant Sserv as Stunnel Server 2 (server)
      Participant Mongo as MongoDB Server
    End
    Note over Scli,Sserv: The wild web
    Cli->>Scli: Query MongoDB
    Scli->>Sserv: Encrypted
    Sserv->>Mongo: Query MongoDB
    Mongo->>Sserv: MongoDB response
    Sserv->>Scli: Encrypted
    Scli->>Cli: MongoDB response
```


## Configuration

**FIXME**
