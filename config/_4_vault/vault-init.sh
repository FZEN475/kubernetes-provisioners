#!/bin/ash
export VAULT_ADDR='https://127.0.0.1:8200'
export VAULT_CACERT='/tmp/certs/ca.crt'
export VAULT_CLIENT_TIMEOUT=300s

echo "curl $(date)" >> /tmp/init.log
wget https://github.com/moparisthebest/static-curl/releases/latest/download/curl-amd64 -O /tmp/curl
chmod +x /tmp/curl
echo "operator init $(date)" >> /tmp/init.log
vault operator init -key-shares=1 -key-threshold=1 > /tmp/init-result.txt
ret=$?
echo "ret $ret $(date)" >> /tmp/init.log
# shellcheck disable=SC3014
if [ "$ret" == "0" ]; then
/tmp/curl -vk --cacert run/secrets/kubernetes.io/serviceaccount/ca.crt\
    -X DELETE \
    -H "Authorization: Bearer $(cat /run/secrets/kubernetes.io/serviceaccount/token)" \
    https://192.168.2.2:6443/api/v1/namespaces/secrets/secrets/vault

/tmp/curl -vk --cacert run/secrets/kubernetes.io/serviceaccount/ca.crt\
    -X POST \
    -d @- \
    -H "Authorization: Bearer $(cat /run/secrets/kubernetes.io/serviceaccount/token)" \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    https://192.168.2.2:6443/api/v1/namespaces/secrets/secrets <<EOF
{
 "apiVersion":"v1",
 "kind" :"Secret",
 "metadata" :{"namespace" :"secrets","name":"vault"},
 "type": "Opaque",
 "stringData": {"key": "$(cat /tmp/init-result.txt | grep 'Unseal Key 1:' | awk '{print $4}')","token": "$(cat /tmp/init-result.txt | grep 'Initial Root Token:' | awk '{print $4}')"}
}
EOF
fi
echo "unseal $(date)" >> /tmp/init.log
# shellcheck disable=SC2155
# shellcheck disable=SC2046
export VAULT_TOKEN=$(/tmp/curl -k --cacert run/secrets/kubernetes.io/serviceaccount/ca.crt\
    -X GET \
    -H "Authorization: Bearer $(cat /run/secrets/kubernetes.io/serviceaccount/token)" \
    -H 'Accept: application/json' \
    https://192.168.2.2:6443/api/v1/namespaces/secrets/secrets/vault | grep \"token\" | awk '{gsub(/"/, "", $2);gsub(/,/, "", $2);print $2}' | base64 -d )

vault operator unseal "$(/tmp/curl -k --cacert run/secrets/kubernetes.io/serviceaccount/ca.crt\
                          -X GET \
                          -H "Authorization: Bearer $(cat /run/secrets/kubernetes.io/serviceaccount/token)" \
                          -H 'Accept: application/json' \
                          https://192.168.2.2:6443/api/v1/namespaces/secrets/secrets/vault | grep \"key\" | awk '{gsub(/"/, "", $2);gsub(/,/, "", $2);print $2}' | base64 -d )"

echo "configure $(date)" >> /tmp/init.log

vault auth enable github || true
vault write auth/github/config organization=FZEN475 || true
vault write auth/github/map/users/Firzen475 value=default || true


vault auth enable kubernetes || true

vault policy write default - <<EOF
path "default**"                        { capabilities = ["read", "list"] }
path "auth/token/lookup-self" { capabilities = ["read"] }
EOF

vault secrets enable pki || true
vault secrets tune -max-lease-ttl=8760h pki || true
cat /tmp/etcd/tls.crt /tmp/etcd/tls.key /tmp/etcd/ca.crt > /tmp/bundle.pem
vault write pki/config/ca pem_bundle=@/tmp/bundle.pem || true
vault write pki/config/urls issuing_certificates="https://vault.secrets.svc:8200/v1/pki/ca" crl_distribution_points="https://vault.secrets.svc:8200/v1/pki/crl" || true
vault write pki/roles/etcd issuer_ref="$(vault read -field=default pki/config/issuers)" require_cn=false allowed_domains=etcd.fzen.pro allow_subdomains=true allow_any_name=true ext_key_usage=Any max_ttl=72h || true
vault policy write pki - <<EOF
path "pki*"                        { capabilities = ["read", "list"] }
path "pki/sign/etcd"    { capabilities = ["create", "update"] }
path "pki/issue/etcd"   { capabilities = ["create"] }
EOF
vault write auth/kubernetes/role/issuer \
    bound_service_account_names=issuer \
    bound_service_account_namespaces=secrets \
    policies=pki \
    ttl=20m || true

vault secrets enable database || true
vault write database/config/pgsql \
    plugin_name="postgresql-database-plugin" \
    connection_url="postgresql://{{username}}:{{password}}@postgresql-primary.storage.svc:5432/postgres" \
    allowed_roles="gitlab" \
    username="postgres" \
    password="$(cat /tmp/pgsql/postgres-password)" \
    password_authentication="scram-sha-256"

vault write auth/kubernetes/role/gitlab-pgsql bound_service_account_names="gitlab-pgsql-sa" bound_service_account_namespaces="secrets" policies=gitlab-pgsql ttl=1h

vault policy write gitlab-pgsql - <<EOF
path "database/static-creds/gitlab"                        { capabilities = ["read", "list"] }
EOF

vault write database/static-roles/gitlab \
  db_name="pgsql" \
  username="gitlab" \
  rotation_statements="ALTER USER {{username}} PASSWORD '{{password}}'" \
  rotation_period="24h"

echo "set jwt token $(date)" >> /tmp/init.log

vault write auth/kubernetes/config token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" kubernetes_host=https://192.168.2.2:6443 kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt >> /tmp/init.log

