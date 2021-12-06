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
## 5. Acceptance Criteria:
Minimum acceptance criteria is a to be able to access a single CloudLab resource seamlessly through ESI without having to share confidential information like passwords. 

This project simulated the cloudlab instance and made a connection with the mock ESI to show power cycling of nodes. The installation details can be found below:

* [MockESI](https://github.com/talhamehboob10/CloudLabonESI/blob/main/mockESI-Installation.md)

* [Cloudlab's Power File](https://github.com/talhamehboob10/CloudLabonESI/blob/main/CloudLab-Installation.md)

## 6. Release Planning

The tentative release planning is given below: 

Release #1: 

First and foremost thing is to understand the working of the CloudLab so in the first release of this project, we will present a tutorial/demo on: 
* How to setup an account on CloudLab 
* How to select a profile for your experiment and reserve the appropriate resources (Memory, Node Cluster, Network etc.)
* How to create a Linux instance on OpenStack  

Release #2: 

The next step is to jump into the CloudLab source code and to look for the part of the code where we need to make changes to allow the communication between CloudLab and ESI. Since the CloudLab is based on EmuLab, so in order to make changes to the source code of CloudLab we need to have thorough understanding of EmuLab. Thus, the second phase will be more focused towards the in-depth understanding of the Emulab source Code and we'll also discuss the installation process of the Emulab source code, which is quite complex itself and requires experience and high level knowledge of systems and networking.  

Release #3: 

In this phase, we are going to focus on the
* "Node management part" where, the first step should be dealing with the power cycling nodes. 
* Certain function calls in the CloudLab source code to invoke ESI commands which will be responsible for the node management. 
* Managing the resource database that maintains a mapping between a logical node name and its physical attributes (MAC address, IPMI credentials, ...) 
* Finding a way to store the ESI name/credentials in CloudLab. 

Release #4 & 5:

* The phase will be a bit more complex and we will be dealing with the network setup in CloudLab, thus it can possibly take more time to get implemented than other tasks. 
* We'll go through the switch management code of CloudLab. For CloudLab to work, it needs to be able to list VLANs and get port membership as well as specify ports and VLANs from a range of VLANs.
* ESI may or may not offer all this functionality. Some functionality like PXE boot might require IPMI serial over LAN for debugging purposes thus this work can get extended to two releases and we might have to implement certain functions in ESI for the above mentioned functionality as we go.
