#!/bin/bash
# launch.sh

set -e  

echo "syntax check..."
ansible-playbook -i inventory/hosts.yaml site.yml --syntax-check

echo "server connectivity check..."
ansible -i inventory/hosts.yaml all -m ping

echo "playbook launch..."
ansible-playbook -i inventory/hosts.yaml playbook.yml -v

echo "Done!"