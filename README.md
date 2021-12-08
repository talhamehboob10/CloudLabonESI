# CloudLab on ESI - Project Description
## 1. Vision and Goals Of The Project:
The Open Cloud Testbed (OCT) is a large scale testbed for cloud computing utilizing high performance network services. It provides bare metal resources to system researchers for their experimentations/investigations. An example of OCT is CloudLab. Often, these testbeds are notoriously overbooked and oversubscribed close to conference deadlines.
​
The goal of this project is to make resources available to cloud computing research with flexibility. This is where ESI comes into play. ESI or the Elastic Secure Infrastructure enables rapid multiplexing of bare-metal servers between clusters. We use one control framework - CloudLab - and modify it such that it can interface with ESI to obtain resources and put them in a CloudLab cluster and make them available to the user community. We implement and evaluate the following functionality:
​
* To set up a configuration of ESI such that it controls all resources housed in a particular rack which in turn helps to put an entire CloudLab testbed rack under ESI control. 
* To set up signaling such that ESI can signal CloudLab control framework about new resources. Additionally, CloudLab can also signal ESI back about resources that have been released so that ESI can put them back in the pool of unassigned resources. 
* To test the mentioned framework thoroughly.
​
## 2. Users/Personas Of The Project:
This project will be used by researchers who subscribe to CloudLab services to evaluate and investigate their experiments. It does not target end-users of websites deployed on cloud. It is a system interface that framework (CloudLab) will call to allocate and reallocate servers. As a stretch goal, the idea of this project is to make it available to users across other control frameworks like Chameleon.
​
​
## 3. Scope and Features Of The Project:

* Dynamic movement of shared hardware between CloudLab & ESI on demand 
* CloudLab working on top of ESI, 
    * making ESI a base/lower layer for shared resources reserved by BU, NE & UMass 
        * enabling seamless movement of node clusters 

    * Doesn’t require CloudLab to have: 
        * Full access to Node Management API of ESI Cluster Nodes 
        * Full access to switches of ESI Cluster Nodes 
        * Access to Login Credential to reach the nodes offered by other platforms 
* Replacement of IPMI & SNMP commands in CloudLab with ESI based commands for Node and Network management 
* In our development setup, both CloudLab and ESI will have full access to all the resources so even if a part of CloudLab is missing an ESI implemented function for some operations, it could still use a native IPMI/SNMP function to perform that operation
* Security: Secure movement of nodes from ESI to CloudLab 
* Efficiency: Increasing aggregate resource efficiency of the datacenter  
## 4. Solution Concept

**Current Architecture**

UMass Amherst owns several racks of servers that they access through CloudLab, which is a software that manages those resources. This also makes these shared resources available to other CloudLab users, and allows them to interconnect with other CloudLab data centers. Similarly, Boston University and Northeastern University have a set of racks that they share between themselves through ESI which is similar software that provides this management service.

To access a resource across these universities is a challenging task that involves sharing sensitive information which is not ideal. Therefore, we propose a solution to bring all the resources from all three universities under a common umbrella for shared access to resources. This can be achieved by allowing all three universities to use CloudLab as the common provider which would work on top of ESI. In doing so, CloudLab would become an ESI user that will be granted permission to use the resources for the duration of the lease for the experiment.

**CloudLab on ESI Architecture** 

Below is a description of the system components that are the building blocks of the architectural design:

* CloudLab: A management framework designed for researchers to run experiments on customizable cloud infrastructure.

* ESI: A service allowing multiple tenants to flexibly allocate bare-metal machines from a pool of available hardware, create networks, attach bare-metal nodes and networks, and optionally provision an operating system.

* Multiple bare-metal machines managed by the three universities.


![Cloudlab on ESI Architecture](https://user-images.githubusercontent.com/60124910/134443639-f8aeba2b-f611-4e33-aeb8-d72ee4f4cc01.png)


Key design decisions and motivation behind them.

Following are the steps to make CloudLab the common platform across all the universities to provision resources and make ESI the middle layer for managing all the bare-metal machines:

* Changing ESI configurations: This will make it the common point of control under which the complete OCT rack resides. 

* Signaling between ESI and CloudLab: Whenever resources are no longer being utilized, CloudLab should signal back to ESI so that these resources can be made available to ESI for putting them back in the pool of unassigned resources.

Above mentioned changes require the following steps:

* Step 1: Identification of the commands that are invoked by CloudLab for all the management operations.
* Step 2: Identification of suitable ESI commands that can be used as a replacement.
* Step 3: Implementation of these calls in the CloudLab code.
## 5. Installation Details:

We are providing the complete installation guide for both the CloudLab's Power Controller file and Mock ESI. The idea is to present all the steps that were involved while setting up the software and configuring important information (e.g. configure variables) so that, the user of this repository can easily setup/install both these software. The installation details for both the Mock ESI and CloudLab's Power Controller file can be found below:

* [MockESI Installation](https://github.com/talhamehboob10/CloudLabonESI/blob/main/mockESI-Installation.md)

* [Cloudlab's Power File Installation](https://github.com/talhamehboob10/CloudLabonESI/blob/main/CloudLab-Installation.md)

## 6. Acceptance Criteria:
This project simulated the cloudlab instance and made a connection with the mock ESI to show power cycling of nodes. 
 
## 7. Release Planning / Project timeline 

Following presents the timeline of the whole project. This comprises of 5 sprints, where in each sprint we tried to accomplish specific tasks, which are mentioned below.  

### Sprint #1: 

First and foremost thing was to understand the working of the CloudLab so in the first sprint of this project, we presented a tutorial/demo on: 
* How to setup an account on CloudLab 
* How to select a profile for your experiment and reserve the appropriate resources (Memory, Node Cluster, Network etc.)
* How to create a Linux instance on OpenStack 

This sprint was mainly focused on providing an overview of what project be, and also an introduction to CloudLab and a demonstration on how CloudLab works. 

### Sprint #2: 

The next step was to jump into the CloudLab source code and to look for the part of the code where we need to make changes to allow the communication between CloudLab and ESI. Since the CloudLab is based on EmuLab, so in order to make changes to the source code of CloudLab we needed to have thorough understanding of EmuLab. Thus, the second phase was be more focused towards the in-depth understanding of the Emulab source Code and we also discuss the installation process of the Emulab source code, which is quite complex itself and requires experience and high level knowledge of systems and networking. By the end of second sprint we were hopeful that we'll get the physical resources to install the Emulab source Code on it. We also discussed briefly, about the VLAN networking in CloudLab and how can we manage the networks in the CloudLab. 

### Sprint #3:  

In this phase, we focused on discussing: 

* What is ESI and Why is it important to this project? 
* Leasing Workflows in ESI 
* Resource Isolation and Sharing in ESI
* Provisioning a node in ESI 

At this point, after discussions with out mentors, we realized that we couldn't allocate the physical resources (nodes, switches etc) for the CloudLab setup, because it wasn't feasible, as the installation of CloudLab was a very difficult thing to do. Also, the same goes for the ESI part as well. So, eventually we decided to mock all the needed functionalities of the CloudLab and ESI. 

### Sprint #4: 

We were able to achieve 3 milestones in this sprint, as shown below: 

* **Mocking ESI:** We were able to mock some of the functionalities of ESI, without worrying about the setup, dependencies and fear of affecting nodes in the production during execution. It was created with Python Django MVT framework. 
* **Power.in - configuring variables:** We were able to run the configure files in order to find the values for configrue variables in the Power.in file, which is essentially responsible for remote cycling of nodes. 
* **Power.in - Code Changes:** We were also able to identify the part of the code in power.in file that needed to be changed in order to call the ESI CLI commands to make the ESI and CloudLab talk to eachother.  


### Sprint #5: 

In this release, we were able to achieve the goals for this project, although it wasn't exactly what we expected initially, i.e., the communication between real CloudLab & ESI software, but we were able to make the Local mock setup of CloudLab to communicate with mock ESI, which proves the idea of this project. Main milestones that we achieved are below: 

* Fully Mocking the Openstack commands for ESI 
* Resolution of errors associated to configure variables in CloudLab 
* Creating a database and populating the tables with data for Power.in
* Running the Power.in file by removing all the dependencies 
* Communication between ESI and CloudLab using Rest API 

The Installation and Implementational details can be seen in above sections. 

## 8. Challenges & Limitations 

During the project, we faced a lot of obstacles, which made this project more interesting and challening. We would like to mention some of them here: 

* Since, we were working with production level code of CloudLab/Emulab and ESI, so it wasn't easy to fully understand everything. 
* We couldn't install these software platforms on the real/physical hardware (nodes, switches etc.), because the installation process was very demanding. 
* The CloudLab codebase is very Big, thus it was hard to find the values for configure variables in this big Codebase. 
* Running the CloudLab Power.in file (Power controller file) was a strenous task as we had to setup the database, and populate the tables with data on our own. 

Finally talking about some of the limitations of this project: 

* Use the actual ESI implementation to invoke the power cycling.
* We invoke power file directly, understand how/where it gets invoked from.
* Understand how CloudLab nodes get stored in database and write a script for ESI nodes to get added.
* Understand how ESI’s authentication would be accommodated (in power_ESI).
* Implementation of Network Management through SNMP 




