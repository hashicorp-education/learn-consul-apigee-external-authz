# Apigee ext_authz integration with Consul Service Mesh

![ext_authz](images/arch.png)

Apigee modules are taken from the Apigee [terraform-modules repo](https://github.com/apigee/terraform-modules), for issues and further assistance please open an issue there.

## Prerequisites

The following must be installed on your local machine, these commands might be required for [local-exec](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource)

- terraform
- gcloud
- curl
- tar
- jq

### Select a GCP project

* Select the GCP project to install resources

```sh
export TF_VAR_project_id=xxx
gcloud config set project $TF_VAR_project_id
gcloud auth login
```

> :warning: **This might take ~30 mins to spin up**

## Create the GKE cluster & Apigee infrastructure

```
terraform -chdir=infra init
terraform -chdir=infra apply -auto-approve
```

## Configure the GKE cluster & Apigee resources

```
export APIGEE_ACCESS_TOKEN="$(gcloud auth print-access-token)"; #Required for the Apigee provider & a custom script

terraform -chdir=app init
terraform -chdir=app apply -auto-approve
```

## Test the setup

* Retrieve GKE creds for local kubectl commands 

```
gcloud container clusters get-credentials \
	$(terraform -chdir=infra output -raw gke_cluster_name) \
    --region $(terraform -chdir=infra output -raw region)
```

* Ping the httpbin service from curl service

```sh
kubectl exec -it deployment/curl -- /bin/sh
curl -i httpbin.default.svc.cluster.local/headers
```

* The response should be HTTP/1.1 200 OK

```sh
HTTP/1.1 200 OK
Server: gunicorn/19.9.0
Date: Wed, 13 Sep 2023 05:32:24 GMT
Connection: keep-alive
Content-Type: application/json
Content-Length: 126
Access-Control-Allow-Origin: *
Access-Control-Allow-Credentials: true
{
  "headers": {
    "Accept": "*/*", 
    "Host": "httpbin.default.svc.cluster.local", 
    "User-Agent": "curl/8.2.1"
  }
}
```

* Apply the `ext_authz` filter

```sh
export TF_VAR_ext_authz=true
terraform -chdir=app apply -auto-approve
```

* Ping the httpbin service from curl service

```sh
kubectl exec -it deployment/curl -- /bin/sh
curl -i httpbin.default.svc.cluster.local/headers
```

* The response should be HTTP/1.1 403 Forbidden

```sh
HTTP/1.1 403 Forbidden
date: Thu, 99 XX 20XX XX:XX:XX GMT
server: envoy
content-length: 0
x-envoy-upstream-service-time: 3
```

> :warning: **It might take ~2mins for Apigee products get registered. Try pinging a few times here.**

* Ping the httpbin service from curl service with the Apigee API key (env var API_KEY is added to the container automatically)

```sh
kubectl exec -it deployment/curl -- /bin/sh
curl -i httpbin.default.svc.cluster.local/headers -H "x-api-key: ${API_KEY}"
```

* The response should be HTTP/1.1 200 OK with custom API headers supplimented by Apigee

```sh
HTTP/1.1 200 OK
server: envoy
date: Thu, 99 XX 20XX XX:XX:XX GMT
content-type: application/json
content-length: 2727
access-control-allow-origin: *
access-control-allow-credentials: true
x-envoy-upstream-service-time: 22
{
    "headers": {
        "Accept": "*/*",
        "Host": "httpbin.default.svc.cluster.local",
        "User-Agent": "curl/8.2.0",
        "X-Api-Key": "developer_client_key_goes_here",
        "X-Apigee-Accesstoken": "",
        "X-Apigee-Api": "httpbin.default.svc.cluster.local",
        "X-Apigee-Apiproducts": "httpbin-product",
        "X-Apigee-Application": "httpbin-app",
        "X-Apigee-Authorized": "true",
        "X-Apigee-Clientid": "developer_client_key_goes_here",
        "X-Apigee-Developeremail": "ahamilton@example.com",
        "X-Apigee-Environment": "env",
        "X-Apigee-Organization": "GCP_ORG_ID",
        "X-Apigee-Scope": "",
        "X-Envoy-Expected-Rq-Timeout-Ms": "15000",
        "X-Forwarded-Client-Cert": "--cert-redacted--"
    }
}
```

### Common errors/debugging tips

- General errors
  - ```Error: Status 401: Message: Unauthorized: "message": "Request had invalid authentication credentials. Expected OAuth 2 access token, login cookie or other valid authentication credential.```
    - gcloud auth login
    - Make sure the `APIGEE_ACCESS_TOKEN` is set as environment variable using export APIGEE_ACCESS_TOKEN="$(gcloud auth print-access-token)";

- Consul debugging tips
  - kubectl get servicedefaults -A
  - kubectl get serviceintentions -A
  - Port forward the envoy proxy on the service_a deployment, for ex.
    - kubectl port-forward deployment/httpbin 19000
    - visit localhost:19000 > config_dump > search for ext_authz

- Apigee debugging tips
  - Monitor the logs of `apigee-remote-service-envoy` pod for error messages
  - Delete the pod > If the Apigee product list shows up as 0 then manually create the product/app/dev with [instructions here](https://cloud.google.com/apigee/docs/api-platform/envoy-adapter/v2.0.x/operation) and ping the httpbin service with the new API key

### Clean up

Destroy the app configuration first, then infrastructure

```sh
terraform -chdir=app destroy -auto-approve
terraform -chdir=infra destroy -auto-approve
```
