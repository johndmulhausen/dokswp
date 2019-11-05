DIGITALOCEAN_ACCESS_TOKEN=fba283a95e3856dea93d9f34c88886a6bdcf7e0e3be4f43e31159f9f35985c96
TIMESTAMP="$(date +%s)"
doctl kubernetes cluster create wordpress-${TIMESTAMP}
doctl kubernetes cluster kubeconfig save wordpress-${TIMESTAMP}
kubectl create secret generic do-operator --from-literal="DIGITALOCEAN_ACCESS_TOKEN=${DIGITALOCEAN_ACCESS_TOKEN}"

kubectl apply -f manifests/do-operator.yaml
kubectl apply -f manifests/mysql.yaml
DBID=$(doctl databases list --format ID --no-header)
DBSTATUS=$(doctl databases get $DBID --format Status --no-header)
while [ "$DBSTATUS" != "online" ]
do
  DBSTATUS=$(doctl databases get $DBID --format Status --no-header)
  echo "Current status: $DBSTATUS"
  echo "Waiting for DB server to come online..."
  sleep 5
done
doctl databases user create $DBID wordpress_user
DBPASSWORD=$(doctl databases user get $DBID wordpress_user --format Password --no-header)
doctl databases db create $DBID wordpress
DBURIRAW=$(doctl databases get $DBID --format URI --no-header)
DBURISERVERRAW=$(echo $DBURIRAW | cut -d'@' -f2)
DBSERVER=$(echo $DBURISERVERRAW | cut -d':' -f1)
DBPORTRAW=$(echo $DBURISERVERRAW | cut -d':' -f2)
DBPORT=$(echo $DBPORTRAW | cut -d'/' -f1)
USEREMAIL=$(doctl account get --format Email --no-header)
sed -- "s/{DBPASSWORD}/$DBPASSWORD/g;s/{USEREMAIL}/$USEREMAIL/g;s/{DBSERVER}/$DBSERVER/g;s/{DBPORT}/$DBPORT/g" values-template.yaml > values.yaml
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
git clone https://github.com/helm/charts.git
helm init --service-account tiller
helm init --upgrade
helm install --name oneclickwordpress -f ./values.yaml charts/stable/wordpress
