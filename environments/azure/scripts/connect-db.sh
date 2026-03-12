#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <DB_HOST>"
    exit 1
fi

# Define variables
DB_HOST=$1
NAMESPACE=default
SOCAT_POD_NAME=psql-db-proxy

# Run a pod with socat to forward traffic
kubectl run -n ${NAMESPACE} --restart=Never --image=alpine/socat \
    ${SOCAT_POD_NAME} -- \
    tcp-listen:5432,fork,reuseaddr \
    tcp-connect:${DB_HOST}:5432 > /dev/null 2>&1

echo
echo "To connect to the PostgreSQL database using a GUI tool like pgAdmin or DBeaver, use the following details:"
echo "--------------------------------------------------------------------------"
echo "Host: localhost"
echo "Port: 5432"
echo "Username: <your_postgresql_username>"
echo "Password: <your_postgresql_password>"
echo "Database: <your_database_name>"
echo
echo "Note: Ensure that this script is running and the port-forwarding is active."

# Forward the local port to the pod
kubectl wait --for=condition=ready pod/${SOCAT_POD_NAME} -n ${NAMESPACE} > /dev/null 2>&1 && echo "Ready to connect" && kubectl port-forward -n ${NAMESPACE} pod/${SOCAT_POD_NAME} 5432:5432 > /dev/null 2>&1

# Clean up the socat pod after the script ends

trap "echo 'Deleting the proxy pod...'; kubectl delete pod ${SOCAT_POD_NAME} -n ${NAMESPACE} > /dev/null 2>&1" EXIT
