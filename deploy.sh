DIGITALOCEAN_ACCESS_TOKEN=fba283a95e3856dea93d9f34c88886a6bdcf7e0e3be4f43e31159f9f35985c96
TIMESTAMP="$(date +%s)"
doctl kubernetes cluster create wordpress-$TIMESTAMP --region sfo2 --auto-upgrade
kubectl create secret generic do-operator --from-literal="DIGITALOCEAN_ACCESS_TOKEN=$DIGITALOCEAN_ACCESS_TOKEN"
kubectl apply -f manifests/do-operator.yaml
kubectl apply -f manifests/mysql.yaml
DBSTATUS="creating"
while [ "$DBSTATUS" != "online" ]
do
  echo "Current status: $DBSTATUS"
  echo "Waiting for DB server to come online..."
  sleep 10
  DBID=$(doctl databases list --format ID --no-header)
  DBSTATUS=$(doctl databases get $DBID --format Status --no-header)
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
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --upgrade --service-account tiller
git clone https://github.com/helm/charts.git
sed -- "s/{DBPASSWORD}/$DBPASSWORD/g;s/{USEREMAIL}/$USEREMAIL/g;s/{DBSERVER}/$DBSERVER/g;s/{DBPORT}/$DBPORT/g" values-production.yaml > charts/stable/wordpress/values.yaml
echo "" > charts/stable/wordpress/requirements.yaml
echo "" > charts/stable/wordpress/requirements.lock
echo "Give helm container a moment to start"
sleep 20
helm install stable/nfs-server-provisioner --set persistence.enabled=true,persistence.size=25Gi
helm install --name oneclickwordpress -f charts/stable/wordpress/values.yaml charts/stable/wordpress
