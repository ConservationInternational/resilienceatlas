#!/usr/bin/env python3
"""
AWS Application Load Balancer Setup Script for ResilienceAtlas

This script creates an Application Load Balancer that routes requests
to staging or production based on the domain name.
"""

import boto3
import argparse
import json
import sys
import time
from botocore.exceptions import ClientError


def create_clients(profile=None):
    """Create and return AWS service clients."""
    try:
        session = boto3.Session(profile_name=profile) if profile else boto3.Session()
        return {
            'elbv2': session.client('elbv2'),
            'ec2': session.client('ec2'),
            'route53': session.client('route53')
        }
    except Exception as e:
        print(f"❌ Error creating AWS clients: {e}")
        sys.exit(1)

def get_vpc_and_subnets(ec2_client, vpc_id=None):
    """Get VPC and subnet information."""
    try:
        if vpc_id:
            vpc_response = ec2_client.describe_vpcs(VpcIds=[vpc_id])
        else:
            # Get default VPC
            vpc_response = ec2_client.describe_vpcs(
                Filters=[{'Name': 'isDefault', 'Values': ['true']}]
            )
        
        if not vpc_response['Vpcs']:
            print("❌ No VPC found. Please specify a VPC ID or create one.")
            return None, None
        
        vpc = vpc_response['Vpcs'][0]
        vpc_id = vpc['VpcId']
        
        # Get public subnets
        subnet_response = ec2_client.describe_subnets(
            Filters=[
                {'Name': 'vpc-id', 'Values': [vpc_id]},
                {'Name': 'map-public-ip-on-launch', 'Values': ['true']}
            ]
        )
        
        subnets = subnet_response['Subnets']
        if len(subnets) < 2:
            print("❌ At least 2 public subnets are required for ALB.")
            return None, None
        
        subnet_ids = [subnet['SubnetId'] for subnet in subnets[:3]]  # Use up to 3 subnets
        
        print(f"✅ Using VPC: {vpc_id}")
        print(f"✅ Using subnets: {', '.join(subnet_ids)}")
        
        return vpc_id, subnet_ids
    
    except ClientError as e:
        print(f"❌ Error getting VPC/subnet information: {e}")
        return None, None

def create_security_group(ec2_client, vpc_id, group_name):
    """Create a security group for the ALB."""
    try:
        response = ec2_client.create_security_group(
            GroupName=group_name,
            Description='Security group for ResilienceAtlas Application Load Balancer',
            VpcId=vpc_id
        )
        
        sg_id = response['GroupId']
        print(f"✅ Created security group: {sg_id}")
        
        # Add rules for HTTP and HTTPS
        ec2_client.authorize_security_group_ingress(
            GroupId=sg_id,
            IpPermissions=[
                {
                    'IpProtocol': 'tcp',
                    'FromPort': 80,
                    'ToPort': 80,
                    'IpRanges': [{'CidrIp': '0.0.0.0/0', 'Description': 'HTTP from anywhere'}]
                },
                {
                    'IpProtocol': 'tcp',
                    'FromPort': 443,
                    'ToPort': 443,
                    'IpRanges': [{'CidrIp': '0.0.0.0/0', 'Description': 'HTTPS from anywhere'}]
                }
            ]
        )
        
        print("✅ Added ingress rules for HTTP and HTTPS")
        return sg_id
    
    except ClientError as e:
        if e.response['Error']['Code'] == 'InvalidGroup.Duplicate':
            # Get existing security group
            response = ec2_client.describe_security_groups(
                Filters=[
                    {'Name': 'group-name', 'Values': [group_name]},
                    {'Name': 'vpc-id', 'Values': [vpc_id]}
                ]
            )
            if response['SecurityGroups']:
                sg_id = response['SecurityGroups'][0]['GroupId']
                print(f"⚠️ Using existing security group: {sg_id}")
                return sg_id
        
        print(f"❌ Error creating security group: {e}")
        return None

def create_target_groups(elbv2_client, vpc_id):
    """Create target groups for staging, production, and their Martin tile servers.
    
    SINGLE-INSTANCE MODE:
    - Production frontend/backend uses port 3000
    - Staging frontend/backend uses port 4000
    - Production Martin uses port 3002
    - Staging Martin uses port 4002
    All target groups point to the same EC2 instance.
    """
    target_groups = {}
    
    environments = [
        {'name': 'staging', 'port': 3000, 'health_check_path': '/'},
        {'name': 'production', 'port': 4000, 'health_check_path': '/'},
        {'name': 'martin-staging', 'port': 4002, 'health_check_path': '/health'},
        {'name': 'martin-production', 'port': 3002, 'health_check_path': '/health'},
    ]
    
    for env in environments:
        try:
            # Martin target groups don't have 'resilienceatlas-' prefix
            if env['name'].startswith('martin-'):
                tg_name = env['name']
            else:
                tg_name = f"resilienceatlas-{env['name']}"
            
            response = elbv2_client.create_target_group(
                Name=tg_name,
                Protocol='HTTP',
                Port=env['port'],
                VpcId=vpc_id,
                HealthCheckPath=env['health_check_path'],
                HealthCheckProtocol='HTTP',
                HealthCheckPort='traffic-port',
                HealthCheckIntervalSeconds=30,
                HealthCheckTimeoutSeconds=5,
                HealthyThresholdCount=2,
                UnhealthyThresholdCount=3,
                TargetType='instance',
                Tags=[
                    {'Key': 'Name', 'Value': tg_name},
                    {'Key': 'Environment', 'Value': env['name']},
                    {'Key': 'Project', 'Value': 'ResilienceAtlas'}
                ]
            )
            
            tg_arn = response['TargetGroups'][0]['TargetGroupArn']
            target_groups[env['name']] = tg_arn
            print(f"✅ Created target group for {env['name']}: {tg_arn}")
            
        except ClientError as e:
            if e.response['Error']['Code'] == 'DuplicateTargetGroupName':
                # Get existing target group
                response = elbv2_client.describe_target_groups(Names=[tg_name])
                if response['TargetGroups']:
                    tg_arn = response['TargetGroups'][0]['TargetGroupArn']
                    target_groups[env['name']] = tg_arn
                    print(f"⚠️ Using existing target group for {env['name']}: {tg_arn}")
            else:
                print(f"❌ Error creating target group for {env['name']}: {e}")
                return None
    
    return target_groups

def create_load_balancer(elbv2_client, subnet_ids, security_group_id):
    """Create the Application Load Balancer."""
    try:
        lb_name = 'ALB-P-ResAtl-1'
        
        response = elbv2_client.create_load_balancer(
            Name=lb_name,
            Subnets=subnet_ids,
            SecurityGroups=[security_group_id],
            Scheme='internet-facing',
            Type='application',
            IpAddressType='ipv4',
            Tags=[
                {'Key': 'Name', 'Value': lb_name},
                {'Key': 'Project', 'Value': 'ResilienceAtlas'}
            ]
        )
        
        lb_arn = response['LoadBalancers'][0]['LoadBalancerArn']
        lb_dns = response['LoadBalancers'][0]['DNSName']
        
        print(f"✅ Created load balancer: {lb_arn}")
        print(f"✅ Load balancer DNS: {lb_dns}")
        
        return lb_arn, lb_dns
    
    except ClientError as e:
        if e.response['Error']['Code'] == 'DuplicateLoadBalancerName':
            # Get existing load balancer
            response = elbv2_client.describe_load_balancers(Names=[lb_name])
            if response['LoadBalancers']:
                lb = response['LoadBalancers'][0]
                lb_arn = lb['LoadBalancerArn']
                lb_dns = lb['DNSName']
                print(f"⚠️ Using existing load balancer: {lb_arn}")
                print(f"⚠️ Load balancer DNS: {lb_dns}")
                return lb_arn, lb_dns
        
        print(f"❌ Error creating load balancer: {e}")
        return None, None

def add_martin_http_rules(elbv2_client, http_listener_arn, target_groups):
    """Add forwarding rules for Martin tile hosts on the HTTP listener.
    
    CloudFront terminates SSL and connects to the ALB over HTTP (port 80),
    sending the original Host header.  These rules forward Martin tile
    requests to the correct target group before the default HTTPS-redirect
    action fires.
    """
    rules = [
        {
            'priority': 15,
            'host': 'martin.staging.resilienceatlas.org',
            'tg_key': 'martin-staging',
            'label': 'Martin staging',
        },
        {
            'priority': 25,
            'host': 'martin.resilienceatlas.org',
            'tg_key': 'martin-production',
            'label': 'Martin production',
        },
    ]
    
    for rule in rules:
        tg_arn = target_groups.get(rule['tg_key'])
        if not tg_arn or 'PENDING' in str(tg_arn):
            print(f"⚠️ Skipping {rule['label']} HTTP rule — target group not ready")
            continue
        
        # Try to find and modify existing rule at this priority
        try:
            existing_rules = elbv2_client.describe_rules(ListenerArn=http_listener_arn)
            rule_arn = None
            for existing_rule in existing_rules['Rules']:
                if existing_rule.get('Priority') == str(rule['priority']):
                    rule_arn = existing_rule['RuleArn']
                    break
            
            if rule_arn:
                # Modify existing rule
                elbv2_client.modify_rule(
                    RuleArn=rule_arn,
                    Conditions=[
                        {
                            'Field': 'host-header',
                            'Values': [rule['host']]
                        }
                    ],
                    Actions=[
                        {
                            'Type': 'forward',
                            'TargetGroupArn': tg_arn
                        }
                    ]
                )
                print(f"✅ Updated HTTP rule: {rule['host']} → {rule['label']} (priority {rule['priority']})")
            else:
                # Create new rule
                elbv2_client.create_rule(
                    ListenerArn=http_listener_arn,
                    Priority=rule['priority'],
                    Conditions=[
                        {
                            'Field': 'host-header',
                            'Values': [rule['host']]
                        }
                    ],
                    Actions=[
                        {
                            'Type': 'forward',
                            'TargetGroupArn': tg_arn
                        }
                    ]
                )
                print(f"✅ Added HTTP rule: {rule['host']} → {rule['label']} (priority {rule['priority']})")
        except ClientError as e:
            print(f"❌ Error updating HTTP rule for {rule['label']}: {e}")


def update_martin_https_rules(elbv2_client, https_listener_arn, target_groups):
    """Update forwarding rules for Martin tile hosts on the HTTPS listener.
    
    Updates existing rules at priorities 15 and 25 to use the new martin subdomain.
    """
    rules = [
        {
            'priority': 15,
            'host': 'martin.staging.resilienceatlas.org',
            'tg_key': 'martin-staging',
            'label': 'Martin staging',
        },
        {
            'priority': 25,
            'host': 'martin.resilienceatlas.org',
            'tg_key': 'martin-production',
            'label': 'Martin production',
        },
    ]
    
    for rule in rules:
        tg_arn = target_groups.get(rule['tg_key'])
        if not tg_arn or 'PENDING' in str(tg_arn):
            print(f"⚠️ Skipping {rule['label']} HTTPS rule — target group not ready")
            continue
        
        # Try to find and modify existing rule at this priority
        try:
            existing_rules = elbv2_client.describe_rules(ListenerArn=https_listener_arn)
            rule_arn = None
            for existing_rule in existing_rules['Rules']:
                if existing_rule.get('Priority') == str(rule['priority']):
                    rule_arn = existing_rule['RuleArn']
                    break
            
            if rule_arn:
                # Modify existing rule
                elbv2_client.modify_rule(
                    RuleArn=rule_arn,
                    Conditions=[
                        {
                            'Field': 'host-header',
                            'Values': [rule['host']]
                        }
                    ],
                    Actions=[
                        {
                            'Type': 'forward',
                            'TargetGroupArn': tg_arn
                        }
                    ]
                )
                print(f"✅ Updated HTTPS rule: {rule['host']} → {rule['label']} (priority {rule['priority']})")
            else:
                # Create new rule
                elbv2_client.create_rule(
                    ListenerArn=https_listener_arn,
                    Priority=rule['priority'],
                    Conditions=[
                        {
                            'Field': 'host-header',
                            'Values': [rule['host']]
                        }
                    ],
                    Actions=[
                        {
                            'Type': 'forward',
                            'TargetGroupArn': tg_arn
                        }
                    ]
                )
                print(f"✅ Added HTTPS rule: {rule['host']} → {rule['label']} (priority {rule['priority']})")
        except ClientError as e:
            print(f"❌ Error updating HTTPS rule for {rule['label']}: {e}")


def create_listeners(elbv2_client, lb_arn, target_groups):
    """Create or use existing listeners with rules for domain-based routing."""
    try:
        # Check for existing listeners first
        print("🔍 Checking for existing listeners...")
        listeners_response = elbv2_client.describe_listeners(LoadBalancerArn=lb_arn)
        
        http_listener_arn = None
        https_listener_arn = None
        
        for listener in listeners_response.get('Listeners', []):
            if listener['Protocol'] == 'HTTP' and listener['Port'] == 80:
                http_listener_arn = listener['ListenerArn']
                print(f"✅ Found existing HTTP listener: {http_listener_arn}")
            elif listener['Protocol'] == 'HTTPS' and listener['Port'] == 443:
                https_listener_arn = listener['ListenerArn']
                print(f"✅ Found existing HTTPS listener: {https_listener_arn}")
        
        # Create HTTP listener only if it doesn't exist
        if not http_listener_arn:
            print("📝 Creating new HTTP listener...")
            response = elbv2_client.create_listener(
                LoadBalancerArn=lb_arn,
                Protocol='HTTP',
                Port=80,
                DefaultActions=[
                    {
                        'Type': 'redirect',
                        'RedirectConfig': {
                            'Protocol': 'HTTPS',
                            'Port': '443',
                            'StatusCode': 'HTTP_301'
                        }
                    }
                ]
            )

            # AWS returns 'Listeners' (list), not 'Listener' (dict)
            if 'Listeners' not in response or not response['Listeners']:
                print(f"❌ Unexpected response from create_listener (no 'Listeners' key or empty):\n{json.dumps(response, indent=2)}")
                return None

            http_listener_arn = response['Listeners'][0]['ListenerArn']
            print(f"✅ Created HTTP listener (redirects to HTTPS): {http_listener_arn}")

        # Add/update Martin forwarding rules on the HTTP listener
        print("🔄 Updating Martin HTTP listener rules...")
        add_martin_http_rules(elbv2_client, http_listener_arn, target_groups)

        # Handle HTTPS listener
        if https_listener_arn:
            print("🔄 Updating Martin HTTPS listener rules...")
            update_martin_https_rules(elbv2_client, https_listener_arn, target_groups)
        else:
            print("⚠️ HTTPS listener not found - requires SSL certificate setup")
            print("⚠️ You'll need to:")
            print("   1. Request or import SSL certificates in AWS Certificate Manager")
            print("   2. Create HTTPS listener manually with certificate ARN")
            print("   3. Add listener rules for domain-based routing")

        # Return configuration
        return {
            'http_listener_arn': http_listener_arn,
            'https_listener_arn': https_listener_arn,
            'https_setup_required': https_listener_arn is None,
            'target_groups': target_groups
        }
    
    except ClientError as e:
        print(f"❌ Error managing listeners: {e}")
        return None

def generate_https_listener_config(target_groups):
    """Generate configuration for HTTPS listener setup."""
    config = {
        "https_listener": {
            "protocol": "HTTPS",
            "port": 443,
            "ssl_policy": "ELBSecurityPolicy-TLS-1-2-2017-01",
            "certificate_arn": "arn:aws:acm:REGION:ACCOUNT:certificate/CERTIFICATE_ID",
            "default_action": {
                "type": "fixed-response",
                "fixed_response": {
                    "status_code": "404",
                    "content_type": "text/plain",
                    "message_body": "Not Found"
                }
            }
        },
        "listener_rules": [
            {
                "priority": 50,
                "description": "Route martin.staging subdomain to Martin staging tile server",
                "conditions": [
                    {
                        "field": "host-header",
                        "values": ["martin.staging.resilienceatlas.org"]
                    }
                ],
                "actions": [
                    {
                        "type": "forward",
                        "target_group_arn": target_groups['martin-staging']
                    }
                ]
            },
            {
                "priority": 60,
                "description": "Route martin subdomain to Martin production tile server",
                "conditions": [
                    {
                        "field": "host-header",
                        "values": ["martin.resilienceatlas.org"]
                    }
                ],
                "actions": [
                    {
                        "type": "forward",
                        "target_group_arn": target_groups['martin-production']
                    }
                ]
            },
            {
                "priority": 100,
                "conditions": [
                    {
                        "field": "host-header",
                        "values": ["staging.resilienceatlas.org"]
                    }
                ],
                "actions": [
                    {
                        "type": "forward",
                        "target_group_arn": target_groups['staging']
                    }
                ]
            },
            {
                "priority": 200,
                "conditions": [
                    {
                        "field": "host-header",
                        "values": ["resilienceatlas.org", "www.resilienceatlas.org"]
                    }
                ],
                "actions": [
                    {
                        "type": "forward",
                        "target_group_arn": target_groups['production']
                    }
                ]
            }
        ]
    }
    
    return config

def main(profile=None, vpc_id=None):
    """Main function to set up Application Load Balancer."""
    print("🚀 Setting up Application Load Balancer for ResilienceAtlas...")
    
    clients = create_clients(profile)
    
    # Get VPC and subnets
    print("\n🌐 Getting VPC and subnet information...")
    vpc_id, subnet_ids = get_vpc_and_subnets(clients['ec2'], vpc_id)
    if not vpc_id or not subnet_ids:
        sys.exit(1)
    
    # Create security group
    print("\n🔒 Creating security group...")
    sg_name = 'resilienceatlas-alb-sg'
    security_group_id = create_security_group(clients['ec2'], vpc_id, sg_name)
    if not security_group_id:
        sys.exit(1)
    
    # Create target groups
    print("\n🎯 Creating target groups...")
    target_groups = create_target_groups(clients['elbv2'], vpc_id)
    if not target_groups:
        sys.exit(1)
    
    # Create load balancer
    print("\n⚖️ Creating Application Load Balancer...")
    lb_arn, lb_dns = create_load_balancer(clients['elbv2'], subnet_ids, security_group_id)
    if not lb_arn:
        sys.exit(1)
    
    # Create listeners
    print("\n👂 Managing listeners...")
    listener_config = create_listeners(clients['elbv2'], lb_arn, target_groups)
    if not listener_config:
        sys.exit(1)
    
    # Generate HTTPS configuration
    https_config = generate_https_listener_config(target_groups)
    
    # Save configuration to file
    config_file = 'alb_configuration.json'
    with open(config_file, 'w') as f:
        json.dump({
            'load_balancer': {
                'arn': lb_arn,
                'dns_name': lb_dns
            },
            'security_group_id': security_group_id,
            'target_groups': target_groups,
            'listener_config': listener_config,
            'https_config': https_config
        }, f, indent=2)
    
    # Summary
    print("\n" + "="*60)
    print("✅ Application Load Balancer Setup Complete!")
    print("="*60)
    print(f"Load Balancer ARN: {lb_arn}")
    print(f"Load Balancer DNS: {lb_dns}")
    print(f"Security Group ID: {security_group_id}")
    print(f"Target Groups:")
    for env, arn in target_groups.items():
        print(f"  - {env}: {arn}")
    
    print(f"\n📋 Configuration saved to: {config_file}")
    
    print("\n📋 Next Steps:")
    print("1. Request SSL certificates in AWS Certificate Manager for:")
    print("   - resilienceatlas.org")
    print("   - staging.resilienceatlas.org")
    print("2. Create HTTPS listener with SSL certificates")
    print("3. Add listener rules for domain-based routing")
    print("   - martin.staging.resilienceatlas.org → Martin staging (priority 15)")
    print("   - martin.resilienceatlas.org → Martin production (priority 25)")
    print("   - staging.resilienceatlas.org → Staging app (priority 100)")
    print("   - resilienceatlas.org → Production app (priority 200)")
    print("4. Register EC2 instances with target groups:")
    print(f"   - Staging app → {target_groups['staging']}")
    print(f"   - Production app → {target_groups['production']}")
    print(f"   - Staging Martin → {target_groups['martin-staging']}")
    print(f"   - Production Martin → {target_groups['martin-production']}")
    print("5. Update Route53 records to point to ALB DNS name:")
    print("   - martin.staging.resilienceatlas.org → ALB")
    print("   - martin.resilienceatlas.org → ALB")
    print("6. Request SSL certificate covering martin.* subdomains (or wildcard *.resilienceatlas.org)")
    print("7. Set GitHub repository variables:")
    print("   - NEXT_PUBLIC_MARTIN_URL = https://martin.staging.resilienceatlas.org")
    print("   - PRODUCTION_NEXT_PUBLIC_MARTIN_URL = https://martin.resilienceatlas.org")
    
    print("\n🔧 Manual HTTPS Listener Setup Commands:")
    print("Use the AWS CLI or Console to create HTTPS listener with the configuration in alb_configuration.json")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Set up Application Load Balancer for ResilienceAtlas')
    parser.add_argument('--profile', '-p', help='AWS profile name from ~/.aws/credentials')
    parser.add_argument('--vpc-id', help='VPC ID (uses default VPC if not specified)')
    args = parser.parse_args()
    main(profile=args.profile, vpc_id=args.vpc_id)
