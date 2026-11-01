"""remote-build expiry janitor (AWS Lambda, Python 3.12).

Every five minutes, terminate this owner's workers whose remote-build:expires epoch has passed.
A missing or unreadable expiry counts as expired. It can only terminate instances tagged with
its owner (its IAM role says so too). Bootstrap embeds this file in the stack inline, so keep
it under CloudFormation's 4096-character ZipFile limit.
"""
import os
import time

import boto3

OWNER = os.environ['OWNER']


def expired_ids(reservations, now):
    """Instance IDs whose expiry tag is missing, unreadable or in the past."""
    expired = []
    for reservation in reservations:
        for instance in reservation['Instances']:
            tags = {t['Key']: t['Value'] for t in instance.get('Tags', [])}
            try:
                deadline = int(tags['remote-build:expires'])
            except (KeyError, ValueError):
                deadline = 0
            if deadline <= now:
                expired.append(instance['InstanceId'])
    return expired


def handler(event, context):
    ec2 = boto3.client('ec2')
    pages = ec2.get_paginator('describe_instances').paginate(Filters=[
        {'Name': 'tag:remote-build:owner', 'Values': [OWNER]},
        {'Name': 'instance-state-name', 'Values': ['pending', 'running', 'stopping', 'stopped']}])
    now = int(time.time())
    expired = [i for page in pages for i in expired_ids(page['Reservations'], now)]
    if expired:
        # An exception here fails the run, which the stack's error alarm reports.
        ec2.terminate_instances(InstanceIds=expired)
    print({'terminated': expired})
    return {'terminated': expired}
