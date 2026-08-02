# Kubernetes workload basics

Kubernetes runs containerized workloads on a cluster. A Pod is the smallest
deployable unit and can contain one or more closely related containers. A Deployment
manages replicated Pods and supports declarative rollouts. A Service provides a
stable network endpoint for a changing group of Pods selected by labels.

Configuration is normally submitted as YAML manifests. The `metadata` section names
an object and carries labels. The `spec` section describes desired state. Controllers
continuously reconcile observed state toward that desired state.

## Checking Pod health

Start with `kubectl get pods -n <namespace>`. The `READY` column compares ready
containers with total containers, `STATUS` shows states such as `Running`,
`Pending`, or `CrashLoopBackOff`, and `RESTARTS` highlights repeatedly failing
containers. Add `-o wide` when node and Pod IP placement are useful.

Use `kubectl describe pod <pod-name> -n <namespace>` to inspect container state,
readiness conditions, probe failures, scheduling details, and recent events. Use
`kubectl logs <pod-name> -n <namespace>` to read application output; add
`-c <container-name>` for a multi-container Pod and `--previous` to inspect the
previous crashed container instance.

Kubernetes can evaluate three probe types. A readiness probe controls whether a Pod
receives Service traffic. A liveness probe detects a container that should be
restarted. A startup probe protects slow-starting containers from liveness checks
until startup succeeds. A Pod being `Running` does not by itself guarantee that it
is ready to serve traffic, so check both status and readiness.

## API server

The Kubernetes API server exposes the Kubernetes API and is the front door of the
control plane. Clients such as `kubectl`, controllers, and cluster components send
requests to it. It authenticates and authorizes requests, runs admission checks,
validates API objects, and coordinates persistence of cluster state in `etcd`.
Other control-plane components observe desired and current state through the API
server rather than modifying `etcd` directly.

## Secrets

Secrets require careful handling. Encoding a value as base64 is not encryption.
Clusters should use encryption at rest, restricted role-based access control, and
external secret-management integration where appropriate.

Source: Kubernetes documentation, https://kubernetes.io/docs/concepts/
