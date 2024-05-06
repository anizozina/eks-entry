## これはなに

KubernetesとEKSのキャッチアップ、諸々試行錯誤。  
現在の構成

- EKSのControl Planeへのアクセスはprivate
- EKS上のリソースはCloud9上に構築した踏み台からアクセスする
- アプリケーションのDeployはEKS上に展開したArgoCDから行うことを想定
- アプリケーションは1台のALBでnamespaceを跨いでアクセスすることを想定
- ArgoCDへのアクセスは別立てしたALB経由でアクセスする

## 動かし方
### 前提

ArgoCDへのアクセスをTLS経由で行う都合上、Route53上にArgoCD用のホストゾーンの用意と、証明書の用意をしておく。  

### 諸々リソースの生成

環境を汚染したくないので、Dockerコンテナのうえでterraform等を動かせるようにしてる。  
AWSへのアクセスはホスト側にあるcredentialをそのまま使えるようにしている。  
```sh
$ docker compose up -d
$ container_id=$(docker compose ps --format "{{.ID}}") && docker exec -it $container_id /bin/bash
```
で起動してあげる。  

`_.tfenv` を編集してよしなに必要な情報を整える。  
必要に応じて環境変数にAWSのCredentialを置く  

```sh
$ cd ./workspace/terraform
$ terraform init
$ terraform plan -var-file _.tfenv
```

特に問題がなければ `terraform apply -var-file _.tfenv` で適用するとEKSが生成される。  
terraformの適用後、Cloud9のアクセス用のURLが発行されるのでアクセスし、variables.tfで指定しているIAM UserでAWSコンソールにログインする。  


### Cloud9上の操作
まずは必要なコマンド群をインストールする。  
初期化時に実行するスクリプトが動かせれば良かったがどっかのタイミングから動かせなくなったらしい。  

kubectlのインストール
```sh
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.29.0/2024-01-04/bin/linux/amd64/kubectl
chmod +x ./kubectl
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$HOME/bin:$PATH
echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
```
kubectlのアップデート。必要な情報は手元のterraformから取得する
```sh
$ aws eks update-kubeconfig --region ap-northeast-1 --name $cluster_name
```

HELMのインストールと、ALBCの作成
```sh
$ curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 > get_helm.sh
$ chmod 700 get_helm.sh
$ ./get_helm.sh


$ helm repo add eks https://aws.github.io/eks-charts
$ helm repo update eks

# 手元でrole_arnとvpc_idを取得する
$ terraform output -raw irsa_iam_role_arn
$ terraform output -raw vpc_id

# cloud9 で適用
$ helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=eks-investigation \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$role_arn" \
  --set region=ap-northeast-1 \
  --set vpcId=$vpc_id
```
argocdコマンドも用意する
```sh
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

次に、ArgoCDのインストールの準備をする。  
namespaceを作っておいて、argocdの定義を取得する。  
```sh
kubectl create namespace argocd 
curl -O https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

ALBからArgoCD経由でアクセスする際に終端リクエストがHTTPになってしまい、ArgoCD側でリクエストを捌けないので上書きする必要がある。  
Cloud9上で `install-patch.yml` を作っておく  
ネットに転がっている情報と微妙に異なるので、上書きするコマンドはソースから見ておいた方が確実かも。  
ref. https://github.com/argoproj/argo-cd/blob/stable/manifests/install.yaml  
必要なのは `--insecure` のフラグを追加することのみ。  
```yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-server
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  template:
    spec:
      containers:
      - args: 
        - /usr/local/bin/argocd-server
        - --insecure
        name: argocd-server
```

次に `kustomization.yml`  
これもバージョンによっては、なところがあるので適切に。  
```yml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: argocd
resources:
- ./install.yaml
- ./ingress.yml
patchesStrategicMerge:
- ./install-patch.yml
```

最後にALB用のIngressを作成する。  
ドメインと証明書は手元で作っておいたものを。  
```yml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-ingress
  namespace: argocd
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: 'ip'
    alb.ingress.kubernetes.io/backend-protocol-version: HTTP1
    alb.ingress.kubernetes.io/healthcheck-path: /healthz
    alb.ingress.kubernetes.io/success-codes: '200'
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80,"HTTPS": 443}]'
    alb.ingress.kubernetes.io/actions.ssl-redirect: '{"Type": "redirect", "RedirectConfig": { "Protocol": "HTTPS", "Port": "443", "StatusCode": "HTTP_301"}}'
    alb.ingress.kubernetes.io/certificate-arn: $acm_arn
  finalizers:
    - ingress.k8s.aws/resources
  labels:
    app: argocd-ingress
spec:
  ingressClassName: alb
  rules:
  - host: $domain
    http:
      paths:
        - path: /
          backend:
            service:
              name: argocd-server
              port:
                number: 80
          pathType: Prefix
  tls:
  - hosts:
    - $domain
```

`kubectl apply -k ./ -n argocd` でリソースができるはず。  
ちゃんと動作確認ができたら、 `argocd --namespace argocd admin initial-password` でパスワードを取得して、 admin / $passwordでログインできる。

### トラブルシューティング
#### Podsが立ち上がらない
```
4 node(s) had untolerated taint {eks.amazonaws.com/compute-type: fargate}. preemption: 0/4 nodes are available: 4 Preemption is not helpful for scheduling.
```
こんなエラーに見舞われた。  
terraformのfargate_profileでの指定をミスっていて、selectorにnamespaceだけじゃなくラベルも含めていたせいで、立ち上がるPodsがどのFargate Profileに属せば良いのかわからんくて落ちていた。

## 消すとき

削除するときは `terraform destroy` をする前にkubernetes経由で作成したリソースを消す必要がある。  
`kubectl delete -k ~/workspace/manifest/foo`等で消せば多分うまく消せるはず…。