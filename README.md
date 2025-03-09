# pod-cert-requester
An init container to request certs from cert-manager and make available to the rest of the pod


Example deployment spec:

spec:
  serviceAccountName: certreq
  initContainers:
    - name: certreq-init
      #...
      env:
        - name: MY_POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        - name: APPLICATION_LABEL
          value: myapp
        - name: ISSUER_KIND
          value: ClusterIssuer
        - name: ISSUER_NAME
          value: my-ca-issuer
        - name: CERTS_DIR
          value: /certs
        - name: SERVICE_NAME
          value: 
      volumeMounts:
        - name: tls-dist
          mountPath: /certs
spec:
  #...
  volumes:
    - name: tls-dist
      emptyDir:
        medium: "Memory"
        sizeLimit: 32Ki

