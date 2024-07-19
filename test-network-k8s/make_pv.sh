sudo rm -rf /data/pv*

sudo mkdir /data/pv0
sudo mkdir /data/pv1
sudo mkdir /data/pv2

kubectl apply -f pv.yaml

kubectl get pv

