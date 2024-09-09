#!/bin/sh

cd $0;

## Create the example namespace
kubectl apply -f ./namespace.yaml

## Setup RabbitMQ operator
kubectl apply -f https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml

## Create the RabbitMQ instance and wait until it is up
kubectl apply -f ./rabbitmqcluster.yaml
##kubectl wait --for=jsonpath='{.status.phase}'=Running pod/rabbitmq-server-0 --namespace=particular-platform-example

## Apply the platform components
kubectl apply -f ./servicecontrol-monitoring.deployment.yaml
kubectl apply -f ./servicecontrol-audit.statefulset.yaml
kubectl apply -f ./servicecontrol-error.statefulset.yaml
kubectl apply -f ./servicepulse.deployment.yaml

## Create a basic auth password file and import it as a secret
htpasswd -bc .htpasswd foo bar
kubectl create secret generic basic-auth --from-file=./.htpasswd --namespace=particular-platform-example
rm -rf .htpasswd

## Wait for the ingress controller to be ready
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s

## Apply the ingress
kubectl apply -f ./ingress.yaml