#!/usr/bin/env python3
"""
EC2 Instance Management Script for ResilienceAtlas

This script provides utilities for managing EC2 instances including
registration/deregistration from target groups, health checks, and maintenance.

Uses EC2 tags for discovery - no configuration files needed.
Required tags on EC2 instances:
  - Project: ResilienceAtlas
  - Environment: staging or production
"""

import boto3
import sys
import time
from botocore.exceptions import ClientError

# Constants for tag-based discovery
PROJECT_TAG = 'ResilienceAtlas'
TARGET_GROUP_NAME_PREFIX = 'resilienceatlas'


def create_clients():
    """Create and return AWS service clients."""
    try:
        return {
            'ec2': boto3.client('ec2'),
            'elbv2': boto3.client('elbv2')
        }
    except Exception as e:
        print(f"❌ Error creating AWS clients: {e}")
        sys.exit(1)


def find_instance_by_tags(ec2_client, environment):
    """Find EC2 instance by Project and Environment tags."""
    try:
        response = ec2_client.describe_instances(
            Filters=[
                {'Name': 'tag:Project', 'Values': [PROJECT_TAG]},
                {'Name': 'tag:Environment', 'Values': [environment]},
                {'Name': 'instance-state-name', 'Values': ['running', 'stopped', 'pending', 'stopping']}
            ]
        )
        
        instances = []
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                instances.append(instance)
        
        if not instances:
            print(f"❌ No instance found with tags Project={PROJECT_TAG}, Environment={environment}")
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
    instance_id = find_instance_by_tags(clients['ec2'], environment)
    target_group_arn = find_target_group_by_name(clients['elbv2'], environment)
    return instance_id, target_group_arn

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

def get_target_health(elbv2_client, target_group_arn, instance_id):
    """Get the health status of an instance in a target group."""
    try:
        response = elbv2_client.describe_target_health(
            TargetGroupArn=target_group_arn,
            Targets=[{'Id': instance_id, 'Port': 3000}]
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

def register_instance(elbv2_client, target_group_arn, instance_id):
    """Register an instance with a target group."""
    try:
        elbv2_client.register_targets(
            TargetGroupArn=target_group_arn,
            Targets=[{'Id': instance_id, 'Port': 3000}]
        )
        print(f"✅ Registered instance {instance_id} with target group")
        return True
    except ClientError as e:
        print(f"❌ Error registering instance: {e}")
        return False

def deregister_instance(elbv2_client, target_group_arn, instance_id):
    """Deregister an instance from a target group."""
    try:
        elbv2_client.deregister_targets(
            TargetGroupArn=target_group_arn,
            Targets=[{'Id': instance_id, 'Port': 3000}]
        )
        print(f"✅ Deregistered instance {instance_id} from target group")
        return True
    except ClientError as e:
        print(f"❌ Error deregistering instance: {e}")
        return False

def wait_for_health_status(elbv2_client, target_group_arn, instance_id, desired_state, timeout=300):
    """Wait for an instance to reach a desired health state."""
    print(f"⏳ Waiting for instance to reach '{desired_state}' state...")
    
    start_time = time.time()
    while time.time() - start_time < timeout:
        health = get_target_health(elbv2_client, target_group_arn, instance_id)
        
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
    
    clients = create_clients()
    instance_id, target_group_arn = get_instance_and_target_group(clients, environment)
    
    print(f"   Instance ID: {instance_id}")
    
    # Get instance status
    instance_status = get_instance_status(clients['ec2'], instance_id)
    if instance_status:
        print(f"   Instance State: {instance_status['instance_state']}")
        print(f"   Public IP: {instance_status['public_ip']}")
        print(f"   Private IP: {instance_status['private_ip']}")
    
    # Get target health
    target_health = get_target_health(clients['elbv2'], target_group_arn, instance_id)
    if target_health:
        print(f"   Target Health: {target_health['state']}")
        if target_health['reason']:
            print(f"   Health Reason: {target_health['reason']}")

def register_command(environment):
    """Register instance with target group."""
    print(f"🎯 Registering {environment} instance with target group...")
    
    clients = create_clients()
    instance_id, target_group_arn = get_instance_and_target_group(clients, environment)
    
    if register_instance(clients['elbv2'], target_group_arn, instance_id):
        wait_for_health_status(clients['elbv2'], target_group_arn, instance_id, 'healthy')


def deregister_command(environment):
    """Deregister instance from target group."""
    print(f"🎯 Deregistering {environment} instance from target group...")
    
    clients = create_clients()
    instance_id, target_group_arn = get_instance_and_target_group(clients, environment)
    
    if deregister_instance(clients['elbv2'], target_group_arn, instance_id):
        wait_for_health_status(clients['elbv2'], target_group_arn, instance_id, 'unused')


def start_command(environment):
    """Start an instance."""
    print(f"🚀 Starting {environment} instance...")
    
    clients = create_clients()
    instance_id = find_instance_by_tags(clients['ec2'], environment)
    start_instance(clients['ec2'], instance_id)


def stop_command(environment):
    """Stop an instance."""
    print(f"🛑 Stopping {environment} instance...")
    
    clients = create_clients()
    instance_id = find_instance_by_tags(clients['ec2'], environment)
    stop_instance(clients['ec2'], instance_id)

def maintenance_mode(environment, enable=True):
    """Enable or disable maintenance mode."""
    action = "Enabling" if enable else "Disabling"
    print(f"🔧 {action} maintenance mode for {environment}...")
    
    clients = create_clients()
    instance_id, target_group_arn = get_instance_and_target_group(clients, environment)
    
    if enable:
        # Deregister from target group
        deregister_instance(clients['elbv2'], target_group_arn, instance_id)
        wait_for_health_status(clients['elbv2'], target_group_arn, instance_id, 'unused')
        print("✅ Maintenance mode enabled - instance removed from load balancer")
    else:
        # Register with target group
        register_instance(clients['elbv2'], target_group_arn, instance_id)
        wait_for_health_status(clients['elbv2'], target_group_arn, instance_id, 'healthy')
        print("✅ Maintenance mode disabled - instance added to load balancer")

def main():
    """Main function."""
    if len(sys.argv) < 3:
        print("Usage: python3 manage_ec2_instances.py <environment> <command>")
        print()
        print("Environments: staging, production")
        print()
        print("Commands:")
        print("  status          - Show instance and target group status")
        print("  register        - Register instance with target group")
        print("  deregister      - Remove instance from target group")
        print("  start           - Start the EC2 instance")
        print("  stop            - Stop the EC2 instance")
        print("  maintenance-on  - Enable maintenance mode (remove from ALB)")
        print("  maintenance-off - Disable maintenance mode (add to ALB)")
        print()
        print("Note: Instances are discovered by EC2 tags:")
        print("  - Project: ResilienceAtlas")
        print("  - Environment: staging or production")
        print()
        print("Target groups are discovered by name: resilienceatlas-<environment>")
        sys.exit(1)
    
    environment = sys.argv[1]
    command = sys.argv[2]
    
    if environment not in ['staging', 'production']:
        print("❌ Environment must be 'staging' or 'production'")
        sys.exit(1)
    
    if command == 'status':
        status_command(environment)
    elif command == 'register':
        register_command(environment)
    elif command == 'deregister':
        deregister_command(environment)
    elif command == 'start':
        start_command(environment)
    elif command == 'stop':
        stop_command(environment)
    elif command == 'maintenance-on':
        maintenance_mode(environment, enable=True)
    elif command == 'maintenance-off':
        maintenance_mode(environment, enable=False)
    else:
        print(f"❌ Unknown command: {command}")
        sys.exit(1)

if __name__ == "__main__":
    main()
