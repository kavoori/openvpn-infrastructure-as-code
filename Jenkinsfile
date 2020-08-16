pipeline {
  agent any
  parameters {
        choice(
            choices: ['us-east-1','us-east-2','eu-north-1','ap-south-1','eu-west-3','eu-west-2','eu-west-1','ap-northeast-2','ap-northeast-1','sa-east-1','ca-central-1','ap-southeast-1','ap-southeast-2','eu-central-1','us-west-1','us-west-2'],
            description: 'Choose the AWS region',
            name: 'REGION')
        choice(
            choices: ['Create' , 'Destroy'],
            description: 'Choose to create or destroy VPN infrastruture',
            name: 'REQUESTED_ACTION')
        string(
            name: 'VPC_PREFIX',
            defaultValue: 'OVPN',
            description: 'A prefix for VPC. A VPC with name {VPC_PREFIX}-{REGION} will be created')
        string(
            name: 'KEY_NAME',
            defaultValue: '',
            description: 'Key Name for the instance when started')
        string(
            name: 'ZONE_ID',
            defaultValue: '',
            description: 'Route53 Hosted Zone ID')
        string(
            name: 'DNS_NAME',
            defaultValue: '',
            description: 'DNS name for the instance')
        string(
            name: 'CLIENT',
            defaultValue: 'client1',
            description: 'Name of the `client.ovpn` file')
    }
  environment {
      AWS_REGION  = "${params.REGION}"
      AWS_ACCESS_KEY_ID     = credentials('vpc-user-aws-secret-key-id')
      AWS_SECRET_ACCESS_KEY = credentials('vpc-user--aws-secret-access-key')
      VPC_NAME_PREFIX = "${params.VPC_PREFIX}"
      KEY_NAME = "${params.KEY_NAME}"
      HOSTED_ZONE_ID = "${params.ZONE_ID}"
      HOSTED_DNS_NAME = "${params.DNS_NAME}"
  }
  stages {
    stage('Create VPC and subnets for the region') {
        when {
                expression { params.REQUESTED_ACTION == 'Create' }
        }
        steps {
            sh '$(pwd)/scripts/create_vpc_for_region.sh ${VPC_NAME_PREFIX} ${AWS_REGION}'
        }
    }

    stage('Create AMI by Packer') {
        when {
                expression { params.REQUESTED_ACTION == 'Create' }
        }
        environment {
          PACKER_AWS_ACCESS_KEY_ID     = credentials('packer-aws-secret-key-id')
          PACKER_AWS_SECRET_ACCESS_KEY = credentials('packer-aws-secret-access-key')
          CLIENT_NAME                  = "${params.CLIENT}"
        }

        steps {
            script {
                    env.AWS_VPC_ID = sh script:'aws --region ${AWS_REGION} ec2 describe-vpcs --filter Name=isDefault,Values=false Name=tag:Name,Values=${VPC_NAME_PREFIX}-${AWS_REGION} --output text --query "Vpcs[0].VpcId"', returnStdout: true
                    env.AWS_SUBNET_ID = sh script:'aws --region ${AWS_REGION} ec2 describe-subnets --filters "Name=vpcId,Values=${AWS_VPC_ID}" "Name=tag:Name,Values=PublicSubnet" --output text --query "Subnets[0].SubnetId"', returnStdout: true
            }
            ansiColor('xterm') {
                sh 'packer build -color=true -var aws_access_key=${PACKER_AWS_ACCESS_KEY_ID} -var aws_secret_key=${PACKER_AWS_SECRET_ACCESS_KEY} -var region=${AWS_REGION} -var vpc_id=${AWS_VPC_ID} -var subnet_id=${AWS_SUBNET_ID} -var client=${CLIENT_NAME} -var hosted_zone_id=${HOSTED_ZONE_ID} -var dns_name=${HOSTED_DNS_NAME} packer/packer.json'
            }
        }
    }

     stage('Start Instance from AMI created by Packer') {
        when {
                expression { params.REQUESTED_ACTION == 'Create' }
        }
        steps {
            sh '$(pwd)/scripts/start_instance_for_region.sh ${VPC_NAME_PREFIX} ${AWS_REGION} ${KEY_NAME}'
        }
    }

    stage('Update Route53 record with instance IP address') {
        when {
                expression { params.REQUESTED_ACTION == 'Create' }
        }
        steps {
            sh '$(pwd)/scripts/update_route53_for_region.sh ${VPC_NAME_PREFIX} ${AWS_REGION} ${HOSTED_ZONE_ID} ${HOSTED_DNS_NAME}'
        }
    }

    stage('Tear down the VPC') {
        when {
                expression { params.REQUESTED_ACTION == 'Destroy' }
        }
        steps {
            sh '$(pwd)/scripts/delete_vpc_for_region.sh ${VPC_NAME_PREFIX} ${AWS_REGION}'
        }
    }

    stage('Delete AMI and Snapshots') {
        when {
                expression { params.REQUESTED_ACTION == 'Destroy' }
        }
        steps {
            sh '$(pwd)/scripts/delete_ami_and_snapshot_for_region.sh ${AWS_REGION}'
        }
    }
    stage('Archive build artifacts') {
        when {
                expression { params.REQUESTED_ACTION == 'Create' }
        }
        steps {
            archiveArtifacts artifacts: 'ansible/.artifacts/*.ovpn', fingerprint: true
        }
    }
  }
}
