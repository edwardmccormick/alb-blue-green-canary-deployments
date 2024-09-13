#!/bin/bash

# Variables
ApplicationLoadBalancer="arn:aws:elasticloadbalancing:region:account-id:loadbalancer/app/my-load-balancer/id"
BlueTargetGroup="arn:aws:elasticloadbalancing:region:account-id:targetgroup/blue-target-group/id"
GreenTargetGroup="arn:aws:elasticloadbalancing:region:account-id:targetgroup/green-target-group/id"

# Get listener rules for example.com
rules=$(aws elbv2 describe-rules --listener-arn $ApplicationLoadBalancer)

# Check the traffic distribution
BlueWeight=$(echo $rules | jq --arg tg "$BlueTargetGroup" '.Rules[].Actions[] | select(.TargetGroupArn == $tg) | .Weight')
GreenWeight=$(echo $rules | jq --arg tg "$GreenTargetGroup" '.Rules[].Actions[] | select(.TargetGroupArn == $tg) | .Weight')

# Ensure 100% traffic is going to one target group
if [[ "$BlueWeight" -eq 100 ]]; then
    CurrentLiveStack="Blue"
elif [[ "$GreenWeight" -eq 100 ]]; then
    CurrentLiveStack="Green"
else
    echo "Both target groups receiving traffic - please manually resolve this situation and rerun this pipeline."
    exit 1
fi

# Export the variable to Azure DevOps
echo "##vso[task.setvariable variable=CurrentLiveStack]$CurrentLiveStack"
echo "CurrentLiveStack set to $CurrentLiveStack and exported to Azure DevOps"
