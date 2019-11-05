doctl databases create oneclickwordpress --engine mysql --size db-s-2vcpu-4gb --region sfo2 --version 8 --num-nodes 2
DBID=$(doctl databases list --format ID --no-header)
DBSTATUS=$(doctl databases get $DBID --format Status --no-header)
while [ "$DBSTATUS" != "online" ]
do
  DBSTATUS=$(doctl databases get $DBID --format Status --no-header)
  echo "Current status: $DBSTATUS"
  echo "Waiting for DB server to come online..."
  sleep 5
done
echo "Done!"
