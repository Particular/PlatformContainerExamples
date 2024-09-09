#!/bin/sh

cd $0;

## Create the example namespace
kubectl apply -f ./namespace.yaml

## Setup RabbitMQ operator
kubectl apply -f https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml

## Create the RabbitMQ instance and wait until it is up
kubectl apply -f ./rabbitmqcluster.yaml
kubectl wait --for=jsonpath='{.status.phase}'=Running pod/servicebus-server-0

#https://www.rabbitmq.com/docs/man/rabbitmq-diagnostics.8\

## Load the transport configuration values into a configmap
kubectl create configmap transport-config --from-env-file=./transport-config.env

## Install the platform components
kubectl apply -f ./servicecontrol-monitoring.deployment.yaml
kubectl apply -f ./servicecontrol-audit.deployment.yaml
kubectl apply -f ./servicecontrol-error.deployment.yaml
kubectl apply -f ./servicepulse.deployment.yaml

## Wait for the ingress to be ready and apply our config
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
kubectl apply -f ./ingress.yaml