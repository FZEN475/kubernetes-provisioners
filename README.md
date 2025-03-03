# kubernetes-provisioners
## Description
* Поставщик доступа к NFS.
  * StorageClass для PVC.
  * Возможность указать поддиректорию в PVC.annotations.
* cert-manager, trust-manager.
  * Автоматически управляет сертификатами.
  * В качестве корневого сертификата используется сертификат Kubernetes.
  * Цепочка: root-ca -> intermediate-ca -> [Consumers]
  * Интеграция с сертификатами из Vault.
  * <details><summary> Таблица сертификатов </summary>

    | Consumer              | Source       | Consumers                                    | Type   |
    |-----------------------|:-------------|:---------------------------------------------|:-------|
    | ingress               | cert-manager | provisioners/ingress                         | server |
    | vault                 | cert-manager | secrets/vault                                | server |
    | prometheus            | cert-manager | monitoring/prometheus<br/>monitoring/grafena | server |
    | client-etcd           | vault        | storage/minio                                | client |
    | kuber                 | cert-manager | monitoring/dashboard                         | server |
    | minio                 | cert-manager | storage/minio                                | server |
    | pgsql                 | cert-manager | storage/pgsql                                | server |    
    | pgadmin               | cert-manager | storage/pgadmin                              | server |
    | redis                 | cert-manager | storage/redis                                | server |
    | gitlab                | cert-manager | gitlab/gitlab                                | server |  
    | kubernetes-agent-dev  | cert-manager | dev/kubernetes-agent-dev                     | server |
    | kubernetes-agent-prod | cert-manager | dev/kubernetes-agent-prod                    | server |

  </details>
* ingress
  * Чарт [ingress-nginx/ingress-nginx](https://github.com/kubernetes/ingress-nginx).
  * Два контроллера: 
    * [internal](https://github.com/FZEN475/kubernetes-provisioners/blob/main/config/_3_ingress/_1_values-internal.yaml); 
    * [external](https://github.com/FZEN475/kubernetes-provisioners/blob/main/config/_3_ingress/_2_values-external.yaml).
* Vault
  * Данные хранятся на NFS.
  * [Backup](https://github.com/FZEN475/kubernetes-provisioners/blob/main/playbooks/_0_init/_1_install.yaml)
  * [vault-init.sh](https://github.com/FZEN475/kubernetes-provisioners/blob/main/config/_4_vault/vault-init.sh)
    * Если первый запуск.
      * Создание базы с настройками `init -key-shares=1 -key-threshold=1`
      * Создание секрета в kubernetes c key и token.
    * Распечатка базы.
    * Первичная статичная настройка:
      * github
      * kubernetes
      * pki
      * database
  * [Создание секретов](https://github.com/FZEN475/ansible-library?tab=readme-ov-file#add_vault_secret).
  * <details><summary> Таблица секретов </summary>

    | SecretStore       | External |     Dynamic     | Secret name                                                                                                                                                                                                                                 | Comment                                                                                    | 
    |-------------------|:--------:|:---------------:|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|:-------------------------------------------------------------------------------------------|
    | grafana-ss        | &cross;  |     &check;     | monitoring/grafana-secrets                                                                                                                                                                                                                  |                                                                                            |
    | minio-ss          | &cross;  |     &check;     | storage/minio-secrets                                                                                                                                                                                                                       |                                                                                            |
    | storage-minio-css | &check;  |     &check;     | storage/minio-gitlab-secrets<br/>gitlab/gitlab-minio-secrets                                                                                                                                                                                | Учетная запись gitlab для minio;<br/>Ключ доступа к minio в gitlab.                        | 
    | pgsql-ss          | &cross;  | &cross;/&check; | storage/pgsql-secrets<br/>storage/pgadmin-pgsql-secrets                                                                                                                                                                                     | Пароль postgres статический;<br/>PGAdmin использует пароль postgres                        |
    | pgadmin-ss        | &cross;  |     &check;     | storage/pgadmin-secrets                                                                                                                                                                                                                     |                                                                                            |
    | gitlab-pgsql-css  | &check;  |     &check;     | gitlab/gitlab-pgsql-secrets                                                                                                                                                                                                                 | Пароль хранится и ротируется в Vault.                                                      | 
    | redis-ss          | &cross;  |     &check;     | storage/redis-secrets                                                                                                                                                                                                                       | Использует секреты redis-clients-secrets                                                   |
    | storage-redis-css | &check;  |     &check;     | storage/redis-clients-secrets<br/>storage/redis-secrets<br/>gitlab/gitlab-redis-secrets                                                                                                                                                     |                                                                                            | 
    | gitlab-ss         | &cross;  |     &cross;     | gitlab/gitlab-secrets<br/>gitlab/kas-secrets<br/>gitlab/rails-secrets<br/>gitlab/gitaly-secrets<br/>gitlab/registry-secrets<br/>gitlab/registry-connect-secrets<br/>gitlab/pages-secrets<br/>gitlab/runner-secrets<br/>gitlab/shell-secrets | Все пароли статические и [созданы отдельно]();<br/> Пароль runner-secrets не используется. |
    | runners-ss        | &cross;  |     &cross;     | gitlab/runners-secrets<br/>gitlab/runner-no-tag-secrets<br/>gitlab/runner-docker-builder-secrets<br/>gitlab/runner-helm-secrets<br/>gitlab/runner-gitlab-registry-secrets                                                                   | runner-gitlab-registry-secrets для доступа раннеров к закрытым репозиториям gitlab.        | 
    | gitlab-agent-ss   | &cross;  |     &cross;     | dev/gitlab-agent-secrets<br/>prod/gitlab-agent-secrets                                                                                                                                                                                      | gitlab-agent-secrets - токен регистрации агента KAS.                                       |
  
  </details>
  
  * [Пример создания секретов gitlab](https://github.com/FZEN475/kubernetes-provisioners/blob/main/playbooks/_4_vault/_0_gitlab_secrets_example.yaml)

* [reloaer](https://github.com/stakater/Reloader)
  * Перезагрузка pod при изменении ConfigMap или Secrets.
* prometheus
  * Prometheus-adapter - добавляет API: v1beta1.metrics.k8s.io; v1beta1.custom.metrics.k8s.io; v1beta1.external.metrics.k8s.io.
  * Kube-state-metrics - агрегирует метрики kubernetes.
  * Prometheus-node-exporter собирает метрики NODE.
  * Grafana - визуализирует метрики.
  * ConfigMaps:
    * [Настройки Prometheus-adapter](https://github.com/FZEN475/kubernetes-provisioners/blob/main/config/_6_prometheus/config/adapter-rules.yaml).
    * [Настройки prometheus](https://github.com/FZEN475/kubernetes-provisioners/blob/main/config/_6_prometheus/config/prometheus.yml).
    * [Настройки grafana](https://github.com/FZEN475/kubernetes-provisioners/blob/main/config/_6_prometheus/config/dashboard.json).
* kubernetes-dashboard
  * [JWT-token](https://github.com/FZEN475/kubernetes-provisioners/blob/main/config/_7_dashboard/config/dashboard-read-only.yaml).

## Dependency
* [Образ](https://github.com/FZEN475/ansible-image)
* [Library](https://github.com/FZEN475/ansible-library)
* <details><summary> .env </summary>

  ```properties
  TERRAFORM_REPO="https://github.com/FZEN475/kubernetes-provisioners.git"
  #GIT_EXTRA_PARAM="-bdev"
  SECURE_SERVER=""
  SECURE_PATH=""
  LIBRARY="https://github.com/FZEN475/ansible-library.git"
  ``` 
  </details>

* <details><summary> secrets </summary>
  
  ```yaml
  secrets:
    - id_ed25519
    - pgsql_password # Постоянный пароль пользоватьеля postgress
    - gitlab-secrets.yaml # Статические секреты gitlab
  ```
</details>

## Stages
### [init](https://github.com/FZEN475/kubernetes-provisioners/blob/main/playbooks/_0_init/_1_install.yaml)
* Установка CIRDs prometheus как зависимость для cert-manager и vault.
* Создание CronJob для резервного копирования базы vault.
### [NFS-provisioner](https://github.com/FZEN475/kubernetes-provisioners/blob/main/playbooks/_1_NFS/_1_install.yaml)
* Установка чарта.
### [cert-manager, trust-manager](https://github.com/FZEN475/kubernetes-provisioners/blob/main/playbooks/_2_cert-manager/_1_install.yaml)
* Установка cert-manager.
* Установка trust-manager.
* Создание цепочки сертификатов кластера.
* Создание ClusterIssuer для клиентских сертификатов etcd из Vault.
* [Создание сертификатов](https://github.com/FZEN475/kubernetes-provisioners/blob/main/playbooks/_2_cert-manager/_2_certificates.yaml)
### [ingress](https://github.com/FZEN475/kubernetes-provisioners/blob/main/playbooks/_3_ingress/_1_install.yaml)
* Установка двух чартов.
### [vault](https://github.com/FZEN475/kubernetes-provisioners/blob/main/playbooks/_4_vault/_1_install.yaml)
* Установка чарта vault.
* Установка чарта external-secrets.
* Создание [секретов в vault](https://github.com/FZEN475/kubernetes-provisioners/blob/main/playbooks/_4_vault/_2_secrets.yaml).
### [reloaer](https://github.com/FZEN475/kubernetes-provisioners/blob/main/playbooks/_5_reloader/_1_install.yaml)
* Установка чарта.
### [prometheus](https://github.com/FZEN475/kubernetes-provisioners/blob/main/playbooks/_6_prometheus/_1_install.yaml)
* Установка чарта kube-state-metrics.
* [Fix kube-rbac-proxy для kube-state-metrics](https://github.com/FZEN475/kubernetes-provisioners?tab=readme-ov-file#Troubleshoots).
* Установка чарта prometheus.
* Установка чарта prometheus-adapter.
* [Fix kube-rbac-proxy для node-exporter](https://github.com/FZEN475/kubernetes-provisioners?tab=readme-ov-file#Troubleshoots).
* Установка чарта grafana.
### [dashboard](https://github.com/FZEN475/kubernetes-provisioners/blob/main/playbooks/_7_dashboard/_1_install.yaml)
* Установка чарта dashboard.

## Troubleshoots

<!DOCTYPE html>
<table>
  <thead>
    <tr>
      <th>Источник</th>
      <th>Проблема</th>
      <th>Решение</th>
    </tr>
  </thead>
  <tr>
      <td>ingress</td>
      <td>При запросе к nginx-controller-admission: <br/> tls: failed to verify certificate</td>
      <td>

Указать tls-секрет через extraArgs;<br/>
Смонтировать tls-секрет и указать пути из extraArgs;
</td>
  </tr>
  <tr>
      <td>Vault</td>
      <td>В логах аутентификации: <br/> permission denied<br/>"path":"auth/token/lookup-self"</td>
      <td>

У политики default нет разрешений на чтение пути.<br/>
```
path "auth/token/lookup-self" {
    capabilities = ["read"]
}
```
</td>
  </tr>
  <tr>
      <td>Vault</td>
      <td>Перестаёт работать аутентификация store в Vault</td>
      <td>

```shell
kubectl exec -it -n secrets            pod/vault-0 -- ash
export VAULT_ADDR='https://127.0.0.1:8200'
export VAULT_CACERT='/tmp/certs/ca.crt'
export VAULT_CLIENT_TIMEOUT=300s
export VAULT_TOKEN=$(/tmp/curl -k --cacert run/secrets/kubernetes.io/serviceaccount/ca.crt\
    -X GET \
    -H "Authorization: Bearer $(cat /run/secrets/kubernetes.io/serviceaccount/token)" \
    -H 'Accept: application/json' \
    https://192.168.2.2:6443/api/v1/namespaces/secrets/secrets/vault | grep \"token\" | awk '{gsub(/"/, "", $2);gsub(/,/, "", $2);print $2}' | base64 -d )
vault write auth/kubernetes/config token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_host=https://192.168.2.2:6443 kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
```

</td>
  </tr>
  <tr>
      <td>prometheus-adapter</td>
      <td>Не устанавливаются APIService при установке через helm.</td>
      <td>

Заполнить:<br/>.Values.rules.custom<br/>.Values.rules.external<br/>.Values.rules.resource<br/>
Любыми правилами. Потом можно менять редактированием ConfigMap.
</td>
  </tr>
  <tr>
      <td>kube-rbac-proxy</td>
      <td>После успешного развёртывания нет доступа к бекэнду с корректным JWT-токеном.</td>
      <td>

В настройках ConfigMap очистить subresource.
```yaml
authorization:
  resourceAttributes:
    namespace: monitoring
    apiVersion: v1
    resource: services
    subresource:
    name: prometheus-kube-state-metrics
```
</td>
  </tr>
</table>