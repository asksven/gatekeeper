# Install Gatekeeper

This repo is a companion to a few blog posts I wrote about [implementing Gatekeeper as a replacement for pod security policies](https://blog.asksven.io/posts/gatekeeper/)
See also: https://github.com/open-policy-agent/gatekeeper

1. Installing Gatekeeper will create a namespace `gatekeeper-system`. See [here](`https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml`) for more details
1. Install: `kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml`

**Note:** if you are deploying to Kubernetes < 1.14 use `--validate=false`. You should be warned, that without timeouts on the webhook, your API Server could timeout when Gatekeeper is down.

**Note:** On ARM

Currently there are no ARM images provided by the project so I have to build Gatekeeper for ARM on my own, following the instructions from the website:

```bash
export DESTINATION_GATEKEEPER_DOCKER_IMAGE=docker.io/asksven/gatekeeper
export VERSION=latest
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
make docker-buildx REPOSITORY="$DESTINATION_GATEKEEPER_DOCKER_IMAGE"
```

**Note:** `docker buildx` will push your image at the end, so you need to make sure that `DESTINATION_GATEKEEPER_DOCKER_IMAGE` is something you can push to

## Example 1: required labels constraint

### Create the CRD

```bash
kubectl -n gatekeeper-system apply -f example1/templates/k8s_required_labels_template.yaml
```

### Test the impact

In order to understand what impact a constraint will have on your workloads Gatekeeper offers `enforcementAction: dryrun`. As the name suggests applying this constraint will only show you the impact it will have, but not enforce it.

Duw to the fact how Gatekeeper works constraints will not only be checked when objects are created or changed but regularly. In order to avoid any surpises or side-effects you should always make a dry-run to understand what effect the constraint may have on existing workloads.

Apply the dryrun constraint:

```bash
kubectl -n gatekeeper-system apply -f example1/constraints/all-ns-must-have-application-label_dryrun.yaml
```

and then check its status: `kubectl -n gatekeeper-system get K8sRequiredLabels all-ns-must-have-application-label -o yaml`

In the `status` section of the yaml you will see something like:

```bash
apiVersion: constraints.gatekeeper.sh/v1beta1
[...]
status:
  auditTimestamp: "2020-05-18T10:53:42Z"
  byPod:
  - enforced: true
    id: gatekeeper-controller-manager-84c78cfb7f-sl68s
    observedGeneration: 1
  totalViolations: 12
  violations:
  - enforcementAction: dryrun
    kind: Namespace
    message: 'you must provide labels: {"application"}'
    name: default
  - enforcementAction: dryrun
    kind: Namespace
    message: 'you must provide labels: {"application"}'
    name: kube-public
  - enforcementAction: dryrun
    kind: Namespace
    message: 'you must provide labels: {"application"}'
    name: kube-node-lease
  - enforcementAction: dryrun
    kind: Namespace
    message: 'you must provide labels: {"application"}'
    name: gatekeeper-system
```

As namespaces are impacted here the side effect is limited but this will still cause Gatekeeper checking and reporting violations over and over, since the fulfillment of constraints is checked regularly.

In order to avoid this you should either:

- Fix the affected namespaces
- Create exceptions in the section `excludedNamespaces` of the constraint's definition

### Apply the constraint

Once you are sure of the impact and have fixed any foreseeable side-effects you can apply the "real" constraint:

```bash
kubectl -n gatekeeper-system apply -f example1/constraints/all-ns-must-have-application-label.yaml
```

### Test

To test the policy we have two namespace definitions:

- `example1/resources/bad-ns.yaml` is missing the label `application`
- `example1/resources/good-ns.yaml` has the label `application`


`kubectl apply -f example1/resources/bad-ns.yaml` returns the following:

```bash
Error from server ([denied by all-ns-must-have-application-label] you must provide labels: {"application"}): error when creating "example1/resources/bad-ns.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [denied by all-ns-must-have-application-label] you must provide labels: {"application"}
```

`kubectl apply -f example1/resources/good-ns.yaml` returns:

```
namespace/good-prod-ns created
```
