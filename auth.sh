#!/bin/bash

if [ "$1" -ne "$2" ]; then
	exit 0
fi

instance=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
region=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | awk -F\" '/region/ {print $4}')
groups=$(aws ec2 describe-instances --region "$region" --instance-id "$instance" --query "Reservations[*].Instances[*].Tags[?Key=='CanSSH'].Value" --output text)
for group in $groups; do
	users=$(aws iam get-group --group-name "$group" --query "Users[*].UserName" --output text)
	if [ $? -gt 0 ]; then
		exit 1
	fi
	for user in $users; do
		ids=$(aws iam list-ssh-public-keys --user-name "$user" --query "SSHPublicKeys[?Status=='Active'].SSHPublicKeyId" --output text)
		for id in $ids; do
			key=$(aws iam get-ssh-public-key --user-name "$user" --ssh-public-key-id "$id" --encoding SSH --query "SSHPublicKey.SSHPublicKeyBody" --output text)
			echo "$key"
		done
	done
done | sort | uniq