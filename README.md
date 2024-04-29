## これはなに

KubernetesとEKSのキャッチアップで諸々試行錯誤した結果。

ひとまずのゴールとして、異なるNamespaceにDeployされたnginxのコンテナに、1台のALB経由でアクセスできるようにする。

## 動かし方

環境を汚染したくないので、Dockerコンテナのうえでterraform等を動かせるようにしてる。  
AWSへのアクセスはホスト側にあるcredentialをそのまま使えるようにしている。  
```sh
$ docker compose up 
```
で起動してあげる。  

`_.tfenv` を編集してよしなに必要な情報を整える。

```sh
$ cd ./terraform
$ terraform init
$ terraform plan -var-file _.tfenv
```

特に問題がなければ `terraform apply -var-file _.tfenv` で適用するとEKSが生成される。
kubectl経由でClusterをいじれるようにするために以下を実行する。  
`aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)`  

次にhelm経由でALBCを作る。

```sh
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$(terraform output -raw cluster_name) \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$(terraform output -raw irsa_iam_role_arn)"
```

最後にPod等のDeployをする
```sh
$ cd ~/workspace/manifest 
$ kubectl apply -k ./foo
$ kubectl apply -k ./bar
```

EKSにALBが作成され、ALB経由でnginxが見られる。

## 消すとき

削除するときは `terraform destroy` をする前にkubernetes経由で作成したリソースを消す必要がある。  
`kubectl delete -k ~/workspace/manifest/foo`等で消せば多分うまく消せるはず…。