#!/bin/bash

AUTH_TOKEN="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
NAMESPACE="$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)"

CA_CERT_BUNDLE=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

cert_manager_api_base_url="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}/apis/cert-manager.io/v1"
certificate_requests_base_url="${cert_manager_api_base_url}/namespaces/${NAMESPACE}/certificates"
api_base_url="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}/api/v1/namespaces/${NAMESPACE}"

ips=\"127.0.0.1\",\"${MY_POD_IP}\"
dnsnames=\"localhost\",\"${HOSTNAME}\"

echo "Getting services for app ${APPLICATION_LABEL}"
res=$(curl -s \
    --header "Accept: application/json" \
    --header "Authorization: Bearer ${AUTH_TOKEN}" \
    --cacert "${CA_CERT_BUNDLE}" \
    "${api_base_url}/services?labelSelector=app=${APPLICATION_LABEL}")

for svc in $(echo "$res" | jq -r '[.items[].metadata.name | select(. != "None")] | .[]'); do
    dnsnames+=,\"$svc\"
    dnsnames+=,\"${HOSTNAME}.$svc\"
done

for ip in $(echo "$res" | jq -r '[.items[].spec.clusterIP | select(. != "None")] | .[]'); do
    ips+=,\"$ip\"
done

echo "Requesting cert for:"
echo "IPS: $ips"
echo "Names: $dnsnames"

cat << EOF | \
    curl -s -X POST \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer ${AUTH_TOKEN}" \
        --cacert "${CA_CERT_BUNDLE}" \
        --data @- \
        "${certificate_requests_base_url}"
{
    "apiVersion": "cert-manager.io/v1",
    "kind": "Certificate",
    "metadata": {
        "name": "$HOSTNAME",
        "namespace": "$NAMESPACE",
        "labels": {
            "app": "$APPLICATION_LABEL"
        }
    },
    "spec": {
        "secretName": "$HOSTNAME-tls",
        "issuerRef": {
            "kind": "$ISSUER_KIND",
            "name": "$ISSUER_NAME"
        },
        "subject": {"organizations": ["cert-manager"]},
        "duration": "43830h",
        "renewBefore": "360h",
        "dnsNames": [${dnsnames}],
        "ipAddresses": [${ips}]
    }
}
EOF

sleep 10s

res=$(curl -s \
    --header "Accept: application/json" \
    --header "Authorization: Bearer ${AUTH_TOKEN}" \
    --cacert "${CA_CERT_BUNDLE}" \
    "${api_base_url}/secrets/$HOSTNAME-tls")

# Write the cert and the CA to files.
echo "$res" | jq -r '.data."ca.crt"' | base64 -d > "$CERTS_DIR/ca.crt"
echo "$res" | jq -r '.data."tls.crt"' | base64 -d > "$CERTS_DIR/tls.crt"
echo "$res" | jq -r '.data."tls.key"' | base64 -d > "$CERTS_DIR/tls.key"
cat "$CERTS_DIR/tls.crt" "$CERTS_DIR/ca.crt" > "$CERTS_DIR/fullchain.crt"
