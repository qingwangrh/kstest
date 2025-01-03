apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{name}}
  namespace: ks-test
spec:
  storageClassName: {{sc}}
  volumeMode: {{mode}}
  resources:
    requests:
      storage: {{size}}Mi
  accessModes:
    - {{access}}
