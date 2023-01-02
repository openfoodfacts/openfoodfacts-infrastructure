# Infrastructure future - workshop on 11th July 2022

Participants: Alex, Charles, Christian, Stephane, Pierre


## Goals

what goals do we want to achieve?

1. Be able to scale horizontally

  - disk space / scalability is one the main issue
  - network management also

2. Improve both the software and hardware side of the infrastructure

3. Take ecology (carbon impact etc.) into account

4. Human redundancy

  - reduce stress

5. Monitor thresholds, trends and critical alerts

6. Redundancy, geographical PCA/PRA

7. delegate, scale the potential for HR

8. Reduce stress level

9. Decrease the barrier to contribute for people who want to train their models

  - 32 GB RAM, GPU for training

## Solutions

### Priorities

1. Forecast threshold and critical alerts and trends
  - **Identify and document** in one place **thresholds** and **critical things to monitor**
    - => Infra repo on github; 
      rationale:
      - external tool
      - decentralized tool: .md files than can be cloned by everyone
    - Alex
  - Identify and document mega-trends (eg. images weight on disk)
    - Infra repo on github
    - Which trends; what to look for to identify the trends
    - What’s critical and what’s not
    - Who?
  - Software evolutions of the monitoring infrastructure
    - which tools
      - Eg. Elastic search
  - Human process
    - Documented in infrastructure repo.
    - Who for what kind of task?
    - Pipeline to acquire, fidelize and level up competent people/contributors
    - Public infra meetings (40 minutes each month)
      - Prioritization of issues
      - Nearly achieved threshold
      - …
      - Alex, Stéphane, Christian; community: Olivier? Hangy? Syl20? Alligator? SRE’s Meetup in Paris? Admin sys without borders?
    - => Github issues
    - => Automatic issues?
    - => Sentry?

### Human redundancy everywhere

- Documentation:
  - Document global infrastructure
  - => Github openfoodfacts-infrastructure repo
  - => .md files
  - List all systems/areas and who masters what
    - Identify gaps where we have only 1 or 2 persons
      - e.g. zfs
    - Identify owners: technical services, product owner
  - Infrastructure spreadsheet
  - Distinguish OFF’s core infrastructure and peripheral services
    - 3 levels: critical for us, critical for others, peripheral
- Technologies upskilling
  - Fill gaps
  - Skills spreadsheet: Munin, network, MongoDB, Docker, Proxmox, Nginx
    - At least 2 people skilled of each technology
  - Skills table: [CT and VM list of OFF infrastructure](https://docs.google.com/spreadsheets/d/19RePmE_-1V_He73fpMJYukEMjPWNmav1610yjpGKfD0/edit#gid=1717551138)
    - **TODO: fill the spreadsheet (All)**
  - Colleague's courses: ZFS, Docker, Proxmox, …
  - Commercial courses: security (YesWeHack ?),
- diminish complexity where possible
  - some complexity: due to hosting on OVH

### Horizontal scaling

**1rst step: OFF1-OFF2 redundancy.**

- MongoDB on OFF1
- OFF2 hardware + OS  upgrade
  - Proxmox on OFF1/OFF2?
- Ask free to add a 3rd machine to make the migration. This machine could be the future test server for IA.
  - Email to Jean-Claude (Christian).
  - Christian & Stephane are listing hardware needs.
- Allow to test the horizontal scaling.


What main issues do we want to solve?

- Adding hardware easily.
- Disk space and availability:
  a. Scaling with S3.
  b. Software: distinguish cold and hot pictures:
     - some pictures are never asked
  c. Deduplicate.
     - first mesure impact
     - excellent topic for a contributor
  d. When croped images are not the latest one, only keep the crop.
  e. Convert JPEG to webp (-50%).
  f. Decrease resolution for 48Mpixel images (=> 12 Mpixel)

- Priority for disk space:
  - f, e
  - b for the long term

- CPU.
- What is scaling horizontally?
  - MongoDB: OK.
  - Apache: OK.
  - Images?
    - Use software routing to manage data with or without images or STO.
  - STO?


#### Short term

- Disk space: 6 month to solve this issue.
  - Very short term: x3 is possible but doesn’t solve the issue in the long term.
  - 1. Against rsync! => ZFS synchronization
    - OFF1 & OFF2 disks to ZFS
    - **buy 2x2 equivalent disks (+1 in case of emergency).**
- Ask Syl20 for MongoDB optimisation.


Focus on IO:

- on off1 rsync are impacting performance
- on off2 at night it gets slow

Product use cases:

- scan speed
- facet speed
- advanced search speed
- nightly data exports
- \# of concurrent scan requests

Increase modularity: being able to upgrade with confidence

being able to deploy regularly, and with confidence

- what kind of evolutions to achieve these goals?
- what kind of hardware evolutions to follow: 1. products' growth, 2. resource consumption growth (API, web, etc.) and 3. software evolution.
- what short-term evolutions to manage products' growth (6-18 months).

### Decrease the barrier to contribute for people who want to train their models
- 64 GB RAM, GPU for training,
  - Tool server with OSM?

### Potential resources
<https://sre.google/books/>

### Small tasks
- Document Munin in openfoodfacts-infrastructure
- Document what to look for in Munin
- Document monitoring usage
- Add API documentation for the reuse of Robotoff
- Plan de reprise de Robotoff
