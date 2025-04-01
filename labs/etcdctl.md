# etcdctl

etcd stores the current state of the cluster in a key-value store. This is a critical component of Kubernetes, as it holds all the configuration data and state information for the cluster. To manage etcd, we can use the `etcdctl` command-line tool. There is also a utility named `etcdutl` that can work directly against `etcd` data files, but for this lab, we will focus on `etcdctl`, which may result in some deprecation messages.

## Installing etcdctl/etcdutl

The following will be installed on the `k8s-cp` host, so we'll want to shell into that:

```bash
multipass shell k8s-cp
```

The `etcdctl` and `etcdutl` tools can be installed from GitHub. We want to grab the same version as our cluster is using:

```bash
ETCD_VERSION="$(kubectl exec -n kube-system etcd-k8s-cp -- etcdctl version | head -n1 | sed 's/.*: //')"
curl -sSL https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz -o etcd.tar.gz
tar xzf etcd.tar.gz
sudo mv -f etcd-v${ETCD_VERSION}*/etcd* /usr/local/bin/
rm -rf etcd-v${ETCD_VERSION}* etcd.tar.gz
```

## Connecting to etcd

For the CKA exam, you will most likely need to use `etcdctl` with a given endpoint, but we will need to use `etcdutl` to perform our restore here, since we are going to break the cluster and therefore can't use the `etcd` server running in the cluster to perform the restore. This means that we will use `etcdctl` from in the cluster to make our snapshot, and then run `etcdutl` from the host VM to perform the restore.

To connect to `etcd` we'll need specify the CA certificate, client certificate, and client key that are used for secure communication. In our lab setup, these files are located in `/etc/kubernetes/pki/etcd/`. The specific files will be `/etc/kubernetes/pki/etcd/ca.crt` (used for `--trusted-ca-file`), `/etc/kubernetes/pki/etcd/server.crt` (used for `--cert-file`), and `/etc/kubernetes/pki/etcd/server.key` (used for `--key-file`). If you look at the `Command` for the pod you can see all the args being used. Also keep in mind that we are using a host bind mount so that the `/etc/kubernetes/pki/etcd` folder is the same in the `etcd` container and on the host VM. This means that we can list all of the keys currently in `etcd` with the following:

```bash
kubectl exec -n kube-system etcd-k8s-cp -- etcdctl get / --prefix --keys-only --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key
```

## Creating interesting data

So that we can verify our backup and restore process, we need to create some interesting data in `etcd`. In this case, we will create a `ConfigMap` in the default namespace. This will give us something to look for when we restore our snapshot later, to verify it worked.

```bash
kubectl create configmap test --from-literal=foo=bar --dry-run=client -o yaml | kubectl apply -f -
```

We can use `etcdctl` once again to verify that our `ConfigMap` was created and is stored in `etcd`. We can do this by running:

```bash
kubectl exec -n kube-system etcd-k8s-cp -- etcdctl get /registry/configmaps/default/test --prefix --keys-only --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key
```

## Creating a snapshot

Now that we have some interesting data in `etcd`, we can create a snapshot of the current state of `etcd`. This will allow us to restore it later. We will use the `etcdctl snapshot save` command to create the snapshot. The snapshot will be saved to a file in the `/var/lib/etcd` directory, which is mounted from the host VM, thereby giving us access to it from both the container and the host VM.

```bash
kubectl exec -n kube-system etcd-k8s-cp -- /bin/sh -c "
ETCDCTL_API=3 etcdctl snapshot save /var/lib/etcd/snapshot.db --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key"
```

We can verify the snapshot with `etcdutl` on the host VM.

```bash
sudo etcdutl snapshot status /var/lib/etcd/snapshot.db --write-out table
```

## Creating a failure scenario

To simulate a failure scenario, we will delete the `ConfigMap` that we created earlier. This will allow us to test our restore process.

```bash
kubectl delete configmap test
```

We can see this is gone using either `kubectl` or `etcdctl`:

```bash
kubectl get configmap test
kubectl exec -n kube-system etcd-k8s-cp -- etcdctl get /registry/configmaps/default/test --prefix --keys-only --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key
```

## Restoring the snapshot

In order to restore the snapshot, we will need to stop the `etcd` container remove the data. Since `etcd` is running as a static manifest, we can temporarily move the manifest file in order for the pod to disappear (which will break the cluster):

```bash
sudo mv /etc/kubernetes/manifests/etcd.yaml ~/etcd.yaml
```

We can use `crictl` to look at the containers that are running on this node to verify that `etcd` is no longer running:

```bash
sudo crictl ps
```

Now we can remove the existing data, making sure we preserve our snapshot, and do our restore:

```bash
sudo mv /var/lib/etcd/snapshot.db ~/snapshot.db
sudo rm -rf /var/lib/etcd/*
sudo rm -rf /var/lib/etcd/member
sudo etcdutl snapshot restore ~/snapshot.db --data-dir=/var/lib/etcd
```

Now we can start `etcd` back up by moving the manifest file back into place:

```bash
sudo mv ~/etcd.yaml /etc/kubernetes/manifests/etcd.yaml
```

This may cause the API server to get restarted, so you may want to use `crictl` again to see when the `etcd` and `kube-apiserver` pods are back up and running:

```bash
sudo crictl ps
```

## Verifying the restore

Now that the restore is done and the cluster is back in operation, we can check that our `ConfigMap` has been restored successfully. We can do this by running the following command:

```bash
kubectl get configmap test -o yaml
```

If the restore was successful, you should see the `ConfigMap` with the data we created earlier. You can also verify that the data is present in `etcd` by running:

```bash
kubectl exec -n kube-system etcd-k8s-cp -- etcdctl get /registry/configmaps/default/test --prefix --keys-only --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key
```
