# Kubernetes workload basics

Kubernetes runs containerized workloads on a cluster. A Pod is the smallest
deployable unit and can contain one or more closely related containers. A Deployment
manages replicated Pods and supports declarative rollouts. A Service provides a
stable network endpoint for a changing group of Pods selected by labels.

Configuration is normally submitted as YAML manifests. The `metadata` section names
an object and carries labels. The `spec` section describes desired state. Controllers
continuously reconcile observed state toward that desired state.

Secrets require careful handling. Encoding a value as base64 is not encryption.
Clusters should use encryption at rest, restricted role-based access control, and
external secret-management integration where appropriate.

Source: Kubernetes documentation, https://kubernetes.io/docs/concepts/
