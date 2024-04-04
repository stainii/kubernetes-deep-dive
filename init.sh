#!/bin/bash

all_nodes_ready() {
    # Get the status of all nodes, looking for the "Ready" condition
    nodes_status=$(kubectl get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}')

    for status in $nodes_status; do
        if [ "$status" != "True" ]; then
            return 1
        fi
    done

    return 0
}

kubeadm init --apiserver-advertise-address $(hostname -i) --pod-network-cidr 10.5.0.0/16
kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter.yaml
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

while true; do
    if all_nodes_ready; then
        echo "All nodes are ready."
        break
    else
        echo "Waiting for all nodes to become ready..."
    fi
    sleep 5
done

kubectl get nodes -o name | xargs -I {} kubectl taint nodes {} node-role.kubernetes.io/control-plane-
