# ec2-ssh-tags

## Scenario
- You have _n_ employees and _m_ AWS EC2 instances
- Each employee needs SSH access to some specific subset of the _m_ machines as a specific user (e.g. `ec2-user`)
- You don't want to share SSH keys
    - Former employees' keys should be easy to revoke
    - Current employees should be able to rotate their keys easily
- You don't want to update `authorized_keys` by hand
- You don't want to use LDAP or run the infrastructure needed for [signed certificates](https://code.facebook.com/posts/365787980419535/scalable-and-secure-access-with-ssh/)

## Idea
Use AWS to manage users and their keys. Make all the servers authenticate SSH logins against IAM using the AWS API. Control which users have access to which servers using IAM groups and EC2 instance tags.

For example:
- You have `developers` (`alice` and `bob`) and `dbadmins` (`claire` and `david`)
- You tag your postgres servers with `CanSSH=dbadmins`
- Only `claire` and `david` are able to SSH in to them
- If someone joins or leaves you update the IAM groups
- If someone's laptop gets stolen they generate a new keypair and save it to their AWS account
- Everything updates automatically

## Instructions
- Give every employee their own IAM user
- Put them in groups based on their role (e.g. "developers", "dbadmins")
    - Create an IAM policy allowing people to [change their own SSH keys and account password](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_delegate-permissions_examples.html#creds-policies-credentials) and attach it to all the groups
- Create an IAM role for the EC2 instances (e.g. "SSHable")
    - Create an IAM policy allowing actions `ec2:DescribeInstances`, `iam:GetGroup`, `iam:ListSSHPublicKeys` and `iam:GetSSHPublicKey` on resource `*` and attach it to the role
- Configure sshd (not manually! bake these changes into your AMIs or Ansible playbook)
    - Copy `auth.sh` to `/etc/ssh/auth.sh` (chown root:root and chmod 755)
    - In `/etc/ssh/sshd_config`, set `AuthorizedKeysCommand /etc/ssh/auth.sh ec2-user %u` and `AuthorizedKeysCommandUser nobody`
        - where `ec2-user` is the local user which employees log in as
    - Ensure the `aws` CLI tool is installed
- When you launch EC2 instances:
    - Associate them with the "SSHable" role
    - Tag them with key "CanSSH" and a whitespace-separated list of group names as the value, e.g. `CanSSH=developers dbadmins thirdgroup fourthgroup`
- Watch out for spaces or special characters in AWS account names