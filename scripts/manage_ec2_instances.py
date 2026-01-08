#!/usr/bin/env python3
"""
EC2 Instance Management Script for ResilienceAtlas

This script provides utilities for managing EC2 instances including
registration/deregistration from target groups, health checks, and maintenance.

Uses EC2 tags for discovery - no configuration files needed.
Required tags on EC2 instances:
  - Project: ResilienceAtlas

SINGLE-INSTANCE MODE: Both staging and production can run on the same instance.
The script discovers the instance by Project tag only.
"""

import boto3
import argparse
import sys
import time
from botocore.exceptions import ClientError

# Constants for tag-based discovery
PROJECT_TAG = 'ResilienceAtlas'
TARGET_GROUP_NAME_PREFIX = 'resilienceatlas'

# Global session for profile support
_session = None


def create_clients(profile=None):
    """Create and return AWS service clients."""
    global _session
    try:
        _session = boto3.Session(profile_name=profile) if profile else boto3.Session()
        return {
            'ec2': _session.client('ec2'),
            'elbv2': _session.client('elbv2')
        }
    except Exception as e:
        print(f"❌ Error creating AWS clients: {e}")
        sys.exit(1)


def find_instance_by_tags(ec2_client):
    """Find EC2 instance by Project tag (single-instance mode)."""
    try:
        response = ec2_client.describe_instances(
            Filters=[
                {'Name': 'tag:Project', 'Values': [PROJECT_TAG]},
                {'Name': 'instance-state-name', 'Values': ['running', 'stopped', 'pending', 'stopping']}
            ]
        )
        
        instances = []
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                instances.append(instance)
        
        if not instances:
            print(f"❌ No instance found with tag Project={PROJECT_TAG}")
            sys.exit(1)
        
        if len(instances) > 1:
            print(f"⚠️  Multiple instances found, using first one: {instances[0]['InstanceId']}")
        
        return instances[0]['InstanceId']
    except ClientError as e:
        print(f"❌ Error finding instance: {e}")
        sys.exit(1)


def find_target_group_by_name(elbv2_client, environment):
    """Find target group by naming convention."""
    target_group_name = f"{TARGET_GROUP_NAME_PREFIX}-{environment}"
    
    try:
        response = elbv2_client.describe_target_groups(Names=[target_group_name])
        
        if response['TargetGroups']:
            return response['TargetGroups'][0]['TargetGroupArn']
        else:
            print(f"❌ Target group '{target_group_name}' not found")
            sys.exit(1)
    except ClientError as e:
        if 'TargetGroupNotFound' in str(e):
            print(f"❌ Target group '{target_group_name}' not found")
            print("   Run setup_alb.py first to create the target group")
            sys.exit(1)
        print(f"❌ Error finding target group: {e}")
        sys.exit(1)


def get_instance_and_target_group(clients, environment):
    """Get instance ID and target group ARN for an environment."""
    instance_id = find_instance_by_tags(clients['ec2'])
    target_group_arn = find_target_group_by_name(clients['elbv2'], environment)
    return instance_id, target_group_arn


def get_frontend_port(environment):
    """Get frontend port for environment."""
    return 4000 if environment == 'production' else 3000

def get_instance_status(ec2_client, instance_id):
    """Get the current status of an EC2 instance."""
    try:
        response = ec2_client.describe_instances(InstanceIds=[instance_id])
        instance = response['Reservations'][0]['Instances'][0]
        
        return {
            'instance_state': instance['State']['Name'],
            'instance_status': 'unknown',  # Would need describe_instance_status for detailed status
            'public_ip': instance.get('PublicIpAddress'),
            'private_ip': instance.get('PrivateIpAddress')
        }
    except ClientError as e:
        print(f"❌ Error getting instance status: {e}")
        return None


def get_target_health(elbv2_client, target_group_arn, instance_id, port):
    """Get the health status of an instance in a target group."""
    try:
        response = elbv2_client.describe_target_health(
            TargetGroupArn=target_group_arn,
            Targets=[{'Id': instance_id, 'Port': port}]
        )
        
        if response['TargetHealthDescriptions']:
            health_desc = response['TargetHealthDescriptions'][0]
            return {
                'state': health_desc['TargetHealth']['State'],
                'reason': health_desc['TargetHealth'].get('Reason', ''),
                'description': health_desc['TargetHealth'].get('Description', '')
            }
        else:
            return {'state': 'not_registered', 'reason': '', 'description': ''}
    except ClientError as e:
        print(f"❌ Error getting target health: {e}")
        return None


def register_instance(elbv2_client, target_group_arn, instance_id, port):
    """Register an instance with a target group."""
    try:
        elbv2_client.register_targets(
            TargetGroupArn=target_group_arn,
            Targets=[{'Id': instance_id, 'Port': port}]
        )
        print(f"✅ Registered instance {instance_id}:{port} with target group")
        return True
    except ClientError as e:
        print(f"❌ Error registering instance: {e}")
        return False


def deregister_instance(elbv2_client, target_group_arn, instance_id, port):
    """Deregister an instance from a target group."""
    try:
        elbv2_client.deregister_targets(
            TargetGroupArn=target_group_arn,
            Targets=[{'Id': instance_id, 'Port': port}]
        )
        print(f"✅ Deregistered instance {instance_id}:{port} from target group")
        return True
    except ClientError as e:
        print(f"❌ Error deregistering instance: {e}")
        return False


def wait_for_health_status(elbv2_client, target_group_arn, instance_id, port, desired_state, timeout=300):
    """Wait for an instance to reach a desired health state."""
    print(f"⏳ Waiting for instance to reach '{desired_state}' state...")
    
    start_time = time.time()
    while time.time() - start_time < timeout:
        health = get_target_health(elbv2_client, target_group_arn, instance_id, port)
        
        if health and health['state'] == desired_state:
            print(f"✅ Instance reached '{desired_state}' state")
            return True
        
        print(f"   Current state: {health['state'] if health else 'unknown'}")
        time.sleep(10)
    
    print(f"❌ Timeout waiting for '{desired_state}' state")
    return False


def start_instance(ec2_client, instance_id):
    """Start an EC2 instance."""
    try:
        ec2_client.start_instances(InstanceIds=[instance_id])
        print(f"✅ Started instance {instance_id}")
        
        # Wait for instance to be running
        waiter = ec2_client.get_waiter('instance_running')
        waiter.wait(InstanceIds=[instance_id])
        print(f"✅ Instance {instance_id} is now running")
        return True
    except ClientError as e:
        print(f"❌ Error starting instance: {e}")
        return False

def stop_instance(ec2_client, instance_id):
    """Stop an EC2 instance."""
    try:
        ec2_client.stop_instances(InstanceIds=[instance_id])
        print(f"✅ Stopped instance {instance_id}")
        
        # Wait for instance to be stopped
        waiter = ec2_client.get_waiter('instance_stopped')
        waiter.wait(InstanceIds=[instance_id])
        print(f"✅ Instance {instance_id} is now stopped")
        return True
    except ClientError as e:
        print(f"❌ Error stopping instance: {e}")
        return False

def status_command(environment):
    """Show status of environment."""
    print(f"📊 Status for {environment} environment:")
    
    global clients
    instance_id, target_group_arn = get_instance_and_target_group(clients, environment)
    port = get_frontend_port(environment)
    
    print(f"   Instance ID: {instance_id}")
    print(f"   Environment Port: {port}")
    
    # Get instance status
    instance_status = get_instance_status(clients['ec2'], instance_id)
    if instance_status:
        print(f"   Instance State: {instance_status['instance_state']}")
        print(f"   Public IP: {instance_status['public_ip']}")
        print(f"   Private IP: {instance_status['private_ip']}")
    
    # Get target health
    target_health = get_target_health(clients['elbv2'], target_group_arn, instance_id, port)
    if target_health:
        print(f"   Target Health: {target_health['state']}")
        if target_health['reason']:
            print(f"   Health Reason: {target_health['reason']}")


def register_command(environment):
    """Register instance with target group."""
    print(f"🎯 Registering {environment} instance with target group...")
    
    global clients
    instance_id, target_group_arn = get_instance_and_target_group(clients, environment)
    port = get_frontend_port(environment)
    
    if register_instance(clients['elbv2'], target_group_arn, instance_id, port):
        wait_for_health_status(clients['elbv2'], target_group_arn, instance_id, port, 'healthy')


def deregister_command(environment):
    """Deregister instance from target group."""
    print(f"🎯 Deregistering {environment} instance from target group...")
    
    global clients
    instance_id, target_group_arn = get_instance_and_target_group(clients, environment)
    port = get_frontend_port(environment)
    
    if deregister_instance(clients['elbv2'], target_group_arn, instance_id, port):
        wait_for_health_status(clients['elbv2'], target_group_arn, instance_id, port, 'unused')


def start_command(environment):
    """Start the instance (affects both environments in single-instance mode)."""
    print(f"🚀 Starting instance (single-instance mode - affects both environments)...")
    
    global clients
    instance_id = find_instance_by_tags(clients['ec2'])
    start_instance(clients['ec2'], instance_id)


def stop_command(environment):
    """Stop the instance (affects both environments in single-instance mode)."""
    print(f"🛑 Stopping instance (single-instance mode - affects both environments)...")
    print(f"⚠️  WARNING: This will stop BOTH staging and production!")
    
    global clients
    instance_id = find_instance_by_tags(clients['ec2'])
    stop_instance(clients['ec2'], instance_id)

def maintenance_mode(environment, enable=True):
    """Enable or disable maintenance mode for a specific environment."""
    action = "Enabling" if enable else "Disabling"
    print(f"🔧 {action} maintenance mode for {environment}...")
    
    global clients
    instance_id, target_group_arn = get_instance_and_target_group(clients, environment)
    port = get_frontend_port(environment)
    
    if enable:
        # Deregister from target group
        deregister_instance(clients['elbv2'], target_group_arn, instance_id, port)
        wait_for_health_status(clients['elbv2'], target_group_arn, instance_id, port, 'unused')
        print(f"✅ Maintenance mode enabled for {environment} - removed from load balancer")
    else:
        # Register with target group
        register_instance(clients['elbv2'], target_group_arn, instance_id, port)
        wait_for_health_status(clients['elbv2'], target_group_arn, instance_id, port, 'healthy')
        print(f"✅ Maintenance mode disabled for {environment} - added to load balancer")


def main():
    """Main function."""
    parser = argparse.ArgumentParser(
        description='Manage EC2 instances for ResilienceAtlas',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Environments: staging, production

Commands:
  status          - Show instance and target group status
  register        - Register instance with target group
  deregister      - Remove instance from target group
  start           - Start the EC2 instance (affects both envs)
  stop            - Stop the EC2 instance (affects both envs)
  maintenance-on  - Enable maintenance mode (remove from ALB)
  maintenance-off - Disable maintenance mode (add to ALB)

SINGLE-INSTANCE MODE: Both staging and production run on same instance.
  - Instance is discovered by tag: Project=ResilienceAtlas
  - Staging uses ports 3000/3001, Production uses ports 4000/4001
  - start/stop commands affect BOTH environments

Target groups are discovered by name: resilienceatlas-<environment>
"""
    )
    parser.add_argument('environment', choices=['staging', 'production'], help='Target environment')
    parser.add_argument('command', choices=['status', 'register', 'deregister', 'start', 'stop', 'maintenance-on', 'maintenance-off'], help='Command to run')
    parser.add_argument('--profile', '-p', help='AWS profile name from ~/.aws/credentials')
    
    args = parser.parse_args()
    
    # Initialize clients with profile
    global clients
    clients = create_clients(args.profile)
    
    if args.command == 'status':
        status_command(args.environment)
    elif args.command == 'register':
        register_command(args.environment)
    elif args.command == 'deregister':
        deregister_command(args.environment)
    elif args.command == 'start':
        start_command(args.environment)
    elif args.command == 'stop':
        stop_command(args.environment)
    elif args.command == 'maintenance-on':
        maintenance_mode(args.environment, enable=True)
    elif args.command == 'maintenance-off':
        maintenance_mode(args.environment, enable=False)


if __name__ == "__main__":
    main()
