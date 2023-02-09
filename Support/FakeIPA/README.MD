```
# Create centos container to host IPA API
podman run -ti --name centostestipasource --hostname centostestipa --network host centos:latest /bin/bash

# Fix centos 8 mirror list 
cd /etc/yum.repos.d/
sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

# Install python
dnf install git python38

# Clone ipa source
git clone https://opendev.org/openstack/ironic-python-agent.git

# Activate venv
python3 -m venv venv
source venv/bin/activate

# Install IPA API Package
pip install -r requirements.txt
python setup.py install

# Run IPA API
ironic-python-agent --api_url http://172.22.0.2:6385
```