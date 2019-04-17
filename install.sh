#!/bin/sh
set -eu


if [ -f /etc/centos-release ]; then yum install -y -q policycoreutils-python; fi

curl -sfL https://get.k3s.io -o install-k3s.sh
sh install-k3s.sh
export PATH=/usr/local/bin:$PATH
while [ `kubectl get nodes -o jsonpath='{range .items[*]}{@.metadata.name}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}' | grep 'Ready=True' | wc -l` -lt 1 ]; do echo -n .; sleep 1; done

# Dynamic storage
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.5/deploy/local-path-storage.yaml
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Use fixed nodePort for traefik http https
while ! kubectl -n kube-system get svc traefik; do sleep 5; done
kubectl -n kube-system patch svc traefik --type=json -p '[{"op":"replace","path":"/spec/ports/0/nodePort","value":30080},{"op":"replace","path":"/spec/ports/1/nodePort","value":30443}]'

# Helm
kubectl --namespace kube-system create serviceaccount tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
curl -sfLO https://storage.googleapis.com/kubernetes-helm/helm-v2.13.1-linux-amd64.tar.gz
tar -zxf helm-v2.13.1-linux-amd64.tar.gz --strip=1 linux-amd64/helm
mv helm /usr/local/bin/
helm --kubeconfig /etc/rancher/k3s/k3s.yaml init --service-account tiller