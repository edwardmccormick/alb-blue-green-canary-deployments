#!/bin/bash

# Variables
ApplicationLoadBalancer="arn:aws:elasticloadbalancing:region:account-id:loadbalancer/app/my-load-balancer/id"
BlueTargetGroup="arn:aws:elasticloadbalancing:region:account-id:targetgroup/blue-target-group/id"
GreenTargetGroup="arn:aws:elasticloadbalancing:region:account-id:targetgroup/green-target-group/id"

# Determine which target group is receiving 100% of the traffic for test.example.com
rules=$(aws elbv2 describe-rules --listener-arn $ApplicationLoadBalancer)
BlueWeight=$(echo $rules | jq --arg tg "$BlueTargetGroup" '.Rules[].Actions[] | select(.TargetGroupArn == $tg) | .Weight')
GreenWeight=$(echo $rules | jq --arg tg "$GreenTargetGroup" '.Rules[].Actions[] | select(.TargetGroupArn == $tg) | .Weight')

# Determine the OncomingLiveStack based on test.example.com traffic
if [[ "$BlueWeight" -eq 100 ]]; then
    OncomingLiveStack="Blue"
elif [[ "$GreenWeight" -eq 100 ]]; then
    OncomingLiveStack="Green"
else
    echo "Both target groups are receiving traffic for test.example.com - manual resolution required."
    exit 1
fi

# Start Canary Deployment: Shift 5% traffic to the OncomingLiveStack
if [[ "$OncomingLiveStack" == "Blue" ]]; then
    aws elbv2 modify-rule --rule-arn $ApplicationLoadBalancer \
        --conditions Field=host-header,Values=example.com \
        --actions Type=forward,TargetGroupArn=$BlueTargetGroup,Weight=5

    echo "5% of traffic directed to Blue target group for example.com"

elif [[ "$OncomingLiveStack" == "Green" ]]; then
    aws elbv2 modify-rule --rule-arn $ApplicationLoadBalancer \
        --conditions Field=host-header,Values=example.com \
        --actions Type=forward,TargetGroupArn=$GreenTargetGroup,Weight=5

    echo "5% of traffic directed to Green target group for example.com"
fi

# Gradually increase the traffic to OncomingLiveStack by 5% every 30 seconds, until it reaches 25%
currentWeight=5
while [[ $currentWeight -lt 25 ]]; do
    sleep 30
    currentWeight=$((currentWeight + 5))
    
    if [[ "$OncomingLiveStack" == "Blue" ]]; then
        aws elbv2 modify-rule --rule-arn $ApplicationLoadBalancer \
            --conditions Field=host-header,Values=example.com \
            --actions Type=forward,TargetGroupArn=$BlueTargetGroup,Weight=$currentWeight
        
        echo "Increased traffic to Blue target group to $currentWeight%"

    elif [[ "$OncomingLiveStack" == "Green" ]]; then
        aws elbv2 modify-rule --rule-arn $ApplicationLoadBalancer \
            --conditions Field=host-header,Values=example.com \
            --actions Type=forward,TargetGroupArn=$GreenTargetGroup,Weight=$currentWeight
        
        echo "Increased traffic to Green target group to $currentWeight%"
    fi
done
