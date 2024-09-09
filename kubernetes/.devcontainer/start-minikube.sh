#/bin/sh

minikube delete

minikube start --memory=12Gb

minikube addons enable ingress

minikube addons enable metrics-server