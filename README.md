# Systems Integrator Skills Evaluator
This provides a simple set of exercises under the [Ignition](http://www.inductiveautomation.com) platform to establish a baseline capability for folks wanting to enter the industrial automation space as a Systems Integrator (SI).

## Getting Started

We're using [Vagrant](http://www.vagrantup.com) to handle the deployment of the environment.  Make sure that you have Vagrant installed by getting a download here:

https://www.vagrantup.com/downloads.html

### Windows

TODO

### Linux / macOS

First, clone this repository to your computer:

```bash
git clone https://github.com/kcollins-ene/evaluator.git
```

Next, start the environment:

```shell
cd evaluator
vagrant up
```
The system will create an provision an Ubuntu 16.04 development environment with Oracle Java8, MySQL, and Ignition 7.9.1 preinstalled.  Next, simply launch a web browser against the forwarded port on your local computer:

http://localhost:8088

## Loading the evaluation gateway

TODO: Integrate the gateway into the installation

## Shutting down the environment

In order to shutdown the environment, run the following command in the `evaluator` folder:

```shell
vagrant halt
```

This will shutdown the virtual machine and release the network port configuration that was setup on launch.

