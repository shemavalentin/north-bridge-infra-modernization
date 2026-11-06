# Northbridge Logistics - EKS Platform as Code

This repository contains the infrastructure-as-code (IaC) and GitOps configurations for the Northbridge Logistics EKS platform modernization.

Historically, cluster add-ons and core components were installed manually via Helm from individual developer laptops, leading to configuration drift, difficult Kubernetes upgrades, and an inability to reliably replicate environments. This project codifies the entire EKS platform using modular Terraform and bootstraps application delivery using Argo CD.

---

## 1. System Architecture

The infrastructure is broken into **three decoupled Terraform layers**, followed by **Argo CD GitOps management** for application workloads.

```
+-----------------------------------------------------------------------+
| LAYER 1: Network                                                      |
| VPC (3 AZs) | Public Subnets (ALBs) | Private Subnets (EKS Nodes/NAT) |
+-----------------------------------------------------------------------+
                                   |
                                   v
+-----------------------------------------------------------------------+
| LAYER 2: Cluster                                                      |
| EKS Control Plane | Managed Node Groups | IRSA Roles | EFS Storage    |
+-----------------------------------------------------------------------+
                                   |
                                   v
+-----------------------------------------------------------------------+
| LAYER 3: Platform Add-ons & GitOps Bootstrap                          |
| ALB Controller | ExternalDNS | cert-manager | External Secrets        |
| Metrics Server | Cluster Autoscaler | Prometheus & Grafana | Fluent Bit|
| Argo CD (App-of-Apps Bootstrap)                                      |
+-----------------------------------------------------------------------+
                                   |
                                   v
+-----------------------------------------------------------------------+
| AFTER BOOTSTRAP: Application Workloads                                |
| Argo CD syncs app manifests from Git to team namespaces               |
+-----------------------------------------------------------------------+
```

### Why Layered State Files?
We explicitly separate state files by layer:
* **Blast Radius Reduction:** A failure or typo in a platform add-on (Layer 3) cannot break or destroy core VPC subnets or EKS nodes (Layers 1 & 2).
* **Speed:** Smaller state files keep `terraform plan` execution fast.
* **Provider Initialization Order:** Prevents failures where Helm or Kubernetes providers attempt to authenticate against an EKS cluster endpoint that does not exist yet.

---

## 2. Prerequisites

Ensure you have the following installed locally before running any deployment commands:

* **Terraform** `>= 1.5.0`
* **AWS CLI v2** configured with appropriate permissions.
* **kubectl** matching the target Kubernetes version (`v1.28+`).
* **Helm v3** (for local debugging if necessary).
* An S3 bucket and DynamoDB table pre-created for remote state storage.

---

## 3. Step-by-Step Deployment Runbook

Deploy the layers strictly in order. Do not skip layers or run them out of sequence.

### Phase 1: Layer 1 - Network
Provisions the VPC, public/private subnets across 3 AZs, route tables, and NAT gateways.

```bash
cd terraform/environments/dev/01-network
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Phase 2: Layer 2 - Cluster & Core Storage
Provisions the EKS control plane, managed node groups, security groups, IRSA IAM roles, and the EFS file system.

```bash
cd ../02-cluster
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Update local kubeconfig to interact with the cluster
aws eks update-kubeconfig --region us-east-1 --name dev-eks
```

### Phase 3: Layer 3 - Platform Add-ons & Argo CD Bootstrap
Installs platform drivers (EBS, EFS), ingress controllers, DNS management, certificate issuers, monitoring stacks, and bootstraps Argo CD.

```bash
cd ../03-platform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

---

## 4. Onboarding a New Application Team

We use a multi-tenant model. Teams are isolated using dedicated namespaces, RBAC rules, Pod Security Standards, LimitRanges, and ResourceQuotas.

To onboard a new application team (e.g., `team-c`):

1. **Add Team Configuration:** Create a new manifest file under `gitops/tenants/team-c.yaml` defining:
   * Namespace `team-c`
   * ResourceQuota (e.g., CPU/Memory caps)
   * LimitRange (sets mandatory default requests/limits so pods schedule cleanly)
   * RBAC RoleBindings restricted to the team's namespace.
2. **Register Argo CD Application:** Add an entry in the `gitops/bootstrap/root-app.yaml` file pointing to the application team’s repository.
3. **Commit & Push:** Commit your changes to the main branch. Argo CD will automatically pick up the change and declare the new environment without requiring `kubectl` or `terraform` access for app engineers.

---

## 5. Teardown Procedure (Clean Destruction)

> **IMPORTANT:** Failure to destroy resources in reverse order will cause `terraform destroy` to hang on VPC subnets due to leftover ENIs and AWS Load Balancers created dynamically by Kubernetes controllers.

### Step 1: Remove Applications from Argo CD
Delete application declarations in Git or run:
```bash
kubectl delete app -n argocd --all
```
Wait for the AWS Load Balancer Controller to delete all underlying ALBs/NLBs in AWS.

### Step 2: Destroy Layer 3 (Platform)
```bash
cd terraform/environments/dev/03-platform
terraform destroy -auto-approve
```

### Step 3: Destroy Layer 2 (Cluster)
```bash
cd ../02-cluster
terraform destroy -auto-approve
```

### Step 4: Destroy Layer 1 (Network)
```bash
cd ../01-network
terraform destroy -auto-approve
```

---

## 6. Architecture Decision Records (ADRs)

* [ADR-001: Multi-Layered Terraform State Isolation](docs/adr/001-state-layering.md)
* [ADR-002: Dual Storage Strategy: EBS vs. EFS](docs/adr/002-ebs-efs-storage-strategy.md)
* [ADR-003: Division of Responsibilities Between Terraform and Argo CD](docs/adr/003-terraform-vs-argocd-boundaries.md)

---

## 7. CI/CD & Security Controls

Every Pull Request automatically triggers a GitHub Actions workflow that executes:
1. `terraform fmt -check` (Formatting standard)
2. `terraform validate` (Syntax check)
3. `tflint` (Terraform linter)
4. `checkov` (Static security analysis for infrastructure-as-code)
5. `terraform plan` (Outputs clean diff as a PR comment for team review)
