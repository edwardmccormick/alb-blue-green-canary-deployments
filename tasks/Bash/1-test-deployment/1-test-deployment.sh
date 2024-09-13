#!/bin/bash

# Variables
ApplicationLoadBalancer="arn:aws:elasticloadbalancing:region:account-id:loadbalancer/app/my-load-balancer/id"
BlueTargetGroup="arn:aws:elasticloadbalancing:region:account-id:targetgroup/blue-target-group/id"
GreenTargetGroup="arn:aws:elasticloadbalancing:region:account-id:targetgroup/green-target-group/id"

# Determine the traffic distribution for example.com and test.example.com
rules=$(aws elbv2 describe-rules --listener-arn $ApplicationLoadBalancer)
exampleBlueWeight=$(echo $rules | jq --arg tg "$BlueTargetGroup" '.Rules[].Actions[] | select(.TargetGroupArn == $tg) | .Weight')
exampleGreenWeight=$(echo $rules | jq --arg tg "$GreenTargetGroup" '.Rules[].Actions[] | select(.TargetGroupArn == $tg) | .Weight')

testBlueWeight=$(echo $rules | jq --arg tg "$BlueTargetGroup" '.Rules[].Actions[] | select(.TargetGroupArn == $tg) | .Weight')
testGreenWeight=$(echo $rules | jq --arg tg "$GreenTargetGroup" '.Rules[].Actions[] | select(.TargetGroupArn == $tg) | .Weight')

# Determine the TargetGroupToReceiveTraffic
if [[ "$exampleBlueWeight" -eq 100 && "$testBlueWeight" -eq 100 ]]; then
    TargetGroupToReceiveTraffic=$GreenTargetGroup
    echo "Redirecting 100% of traffic for test.example.com to the Green target group"
elif [[ "$exampleGreenWeight" -eq 100 && "$testGreenWeight" -eq 100 ]]; then
    TargetGroupToReceiveTraffic=$BlueTargetGroup
    echo "Redirecting 100% of traffic for test.example.com to the Blue target group"
else
    echo "Error - all traffic is not currently going to a single stack. Manual resolution is required before a Blue/Green or Canary deployment can be attempted."
    exit 1
fi

# Shift 100% of traffic for test.example.com to the other stack
aws elbv2 modify-rule --rule-arn $ApplicationLoadBalancer \
    --conditions Field=host-header,Values=test.example.com \
    --actions Type=forward,TargetGroupArn=$TargetGroupToReceiveTraffic,Weight=100

echo "Traffic for test.example.com now directed to $TargetGroupToReceiveTraffic"
