# k8s-lab

Helps you create a lab environment for Kubernetes using Multipass and kubeadm. There are also some [lab exercises](./labs/README.md) to help you practice your skills for the Certified Kubernetes Administrator (CKA) exam.

## Prerequisites

Since [Multipass](https://multipass.run/) works on Linux, macOS and Windows, this tutorial assumes that you have Multipass already installed, allowing it to be a cross platform tutorial. This tutorial also assumes that you have the repo cloned into the directory that you are running the commands from.

## Creating the VMs

First, we need to create the VMs that will be used in the lab. We will create 3 VMs, 1 control plane node and 1 worker. The example below creates the VMs with some recommended resources, but you can try to adjust them if you need/want to.

```bash
multipass launch --name k8s-cp --cpus 2 --memory 2G --disk 20G
multipass launch --name k8s-worker1 --cpus 2 --memory 2G --disk 20G
```

## Staging files on the VMs

> **Note:** If you have special root certificates that need to be installed in the VMs, place them in the `setup/root-cas` folder before running the setup scripts.

To copy all the setup files and set the appropriate permissions, run the following, adjusting for the number of VMs that you have:

```bash
multipass transfer -r setup k8s-cp:/home/ubuntu/setup
multipass exec k8s-cp -- bash -c "chmod +x /home/ubuntu/setup/vm-scripts/*.sh"
multipass transfer -r setup k8s-worker1:/home/ubuntu/setup
multipass exec k8s-worker1 -- bash -c "chmod +x /home/ubuntu/setup/vm-scripts/*.sh"
```

## Basic VM Configuration

Each VM has some basic packages installed and some standard configuration. The script `setup/vm-scripts/setup-vm.sh` will need to be executed on each VM.

```bash
multipass exec k8s-cp -- /home/ubuntu/setup/vm-scripts/setup-vm.sh
multipass exec k8s-worker1 -- /home/ubuntu/setup/vm-scripts/setup-vm.sh
```

## Install the Kubernetes Control Plane

In order to easily forward traffic from the host to the control plane node when accessing the cluster later on, we can pass the IP address of the host as a subject alternative name (SAN) on the certificate for the cluster. Pulling the IP of the host can look different depending on the OS. If instead you don't mind shelling into one of the VMs to run your `kubectl` commands, then you don't need to pass in anything extra.

```bash
multipass exec k8s-cp -- /home/ubuntu/setup/vm-scripts/setup-k8s-cp.sh
```

## Join workers to the cluster

When creating the control plane, `kubeadm` spit out the join command for the cluster, but if you missed it, you can find it again by running `multipass exec k8s-cp -- kubeadm token create --print-join-command` on the control plane node. This command will then need to be ran on the worker nodes. For Bash, PowerShell, and some others, here's a one-liner that can do that:

```bash
multipass exec k8s-worker1 -- bash -c "sudo $(multipass exec k8s-cp -- kubeadm token create --print-join-command)"
```

## Inspecting the cluster

The cluster should be up and running now. To verify this you can shell into the control plane node and run some `kubectl` commands:

```bash
# shell to k8s-cp
multipass shell k8s-cp
```

```bash
# run these commands on the k8s-cp VM

# check that all components are in a good state
kubectl get --raw='/readyz?verbose'

# show all basic resources installed in the cluster at this time
kubectl get all -A
```

## Accessing the cluster without using shell

Multipass has the ability to define aliases for commands run on specific instances. To create an alias of `labctl` that will execute `kubectl` on the control plane node, you can run the following:

```bash
multipass alias k8s-cp:kubectl labctl
```

Multipass will give you instructions on how to add the alias directory to your path, which can let you use the command we just defined directly, otherwise you can run it with `multipass` prefixing it, like this:

```bash
multipass labctl version
```

## Cleaning up

After you are done with these, or if you want to start over again for any reason, just delete the VMs and then run a purge:

```bash
multipass delete k8s-cp
multipass delete k8s-worker1
multipass purge
```
