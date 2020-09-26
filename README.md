# OpenVPN AWS infrastructure as code
A small Jenkins pipeline project to automate the creation (and deletion) of AWS infrastructure using Packer and Ansible to run [OpenVPN](https://en.wikipedia.org/wiki/OpenVPN)  
When used in its entirety, it will:
1. Create VPC infrastructure
2. Uses `packer` and `ansible` to create an AMI with OpenVPN software installed (with supplied configuration) with the help of [EasyRSA](https://github.com/OpenVPN/easy-rsa). (Uses v3.0.8)
3. Starts an instance with the generated AMI
4. Updates Route53 Hosted Zone record with the IP address of the instance to the DNS name chosen
5. Downloads the `.ovpn` file which can be used to connect to the OpenVPN service running on the instance ([OpenVPN Connect](https://openvpn.net/client-connect-vpn-for-mac-os/) client or [Tunnelblick](https://tunnelblick.net/) can be used to import this file)

## Cleaning up the infrastructure
The pipeline also has an option to cleanup the above created infrastructure by choosing the `Destroy` option which will
1. Delete the VPC and all its sub resources
2. Deletes the AMI created in the `Create` operation
3. Deletes the snapshot created in the `Create` operation

## Required information
The Jenkins pipeline expects the following
1. AWS credentials in Jenkins in the [form](https://www.jenkins.io/doc/book/using/using-credentials/) of `vpc-user-aws-secret-key-id` and `vpc-user--aws-secret-access-key` which should have IAM role to create VPC
2. AWS credentials in Jenkins in the [form](https://www.jenkins.io/doc/book/using/using-credentials/) of `packer-aws-secret-key-id` and `packer-aws-secret-access-key` which should have IAM role limited to building an instance
3. A `AWS_REGION` to choose AWS region in which the VPC and the instance will be built
4. An option to `Create` or `Destroy` the infrastructure
5. A `VPC_NAME_PREFIX` to prefix the VPC name. **Note : The name of the VPC will be `VPC_NAME_PREFIX-AWS_REGION`**
6. A `KEY_NAME` to add to the running instance
7. A `HOSTED_ZONE_ID` to identify the Route53 Hosted Zone
8. A `HOSTED_DNS_NAME` to choose a DNS for updating the Route53 record with the IP address of the instance
9. A `CLIENT` to give a name to the `.ovpn` file that is created

## Required executables
The following should be available on the path
1. `aws` cli
2. `packer`
3. `ansible` and `ansible-playbook`

## Other configuration to modify
The following values from `ansible/roles/server/vars/main.yml` are used by `ansible` when creating configuration files to be used by [EasyRSA](https://github.com/OpenVPN/easy-rsa) and ***should*** be changed to suit your needs. See EasyRSA [documentation](https://github.com/OpenVPN/easy-rsa/blob/master/README.quickstart.md) for more details:

```
easy_rsa_vars_country : US
easy_rsa_vars_province : CA
easy_rsa_vars_city : San Francisco
easy_rsa_vars_org : ACME
easy_rsa_vars_email : admin@acme.com
easy_rsa_vars_ou : OU
```
