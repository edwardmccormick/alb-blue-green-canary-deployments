#!/bin/bash

# Variables
ApplicationLoadBalancer="arn:aws:elasticloadbalancing:region:account-id:loadbalancer/app/my-load-balancer/id"
BlueTargetGroup="arn:aws:elasticloadbalancing:region:account-id:targetgroup/blue-target-group/id"
GreenTargetGroup="arn:aws:elasticloadbalancing:region:account-id:targetgroup/green-target-group/id"
BlueEC2="i-0123456789abcdef0" # EC2 instance ID for Blue
GreenEC2="i-0123456789abcdef1" # EC2 instance ID for Green

# Determine which target group is receiving 100% of the traffic for test.example.com
rules=$(aws elbv2 describe-rules --listener-arn $ApplicationLoadBalancer)
BlueWeight=$(echo $rules | jq --arg tg "$BlueTargetGroup" '.Rules[].Actions[] | select(.TargetGroupArn == $tg) | .Weight')
GreenWeight=$(echo $rules | jq --arg tg "$GreenTargetGroup" '.Rules[].Actions[] | select(.TargetGroupArn == $tg) | .Weight')

# Determine the OncomingLiveStack
if [[ "$BlueWeight" -eq 100 ]]; then
    OncomingLiveStack="Blue"
elif [[ "$GreenWeight" -eq 100 ]]; then
    OncomingLiveStack="Green"
else
    echo "Both target groups are receiving traffic for test.example.com - manual resolution required."
    exit 1
fi

# Route 100% of traffic to the same target group for example.com as test.example.com
if [[ "$OncomingLiveStack" == "Blue" ]]; then
    # Route 100% traffic to Blue for example.com
    aws elbv2 modify-rule --rule-arn $ApplicationLoadBalancer \
        --conditions Field=host-header,Values=example.com \
        --actions Type=forward,TargetGroupArn=$BlueTargetGroup,Weight=100

    echo "Routing 100% of traffic to the Blue target group for example.com"
    
    # Confirm that 100% of traffic is routed to Blue
    while : ; do
        newRules=$(aws elbv2 describe-rules --listener-arn $ApplicationLoadBalancer)
        newBlueWeight=$(echo $newRules | jq --arg tg "$BlueTargetGroup" '.Rules[].Actions[] | select(.TargetGroupArn == $tg) | .Weight')
        if [[ "$newBlueWeight" -eq 100 ]]; then
            echo "Confirmed: 100% of traffic is now routed to the Blue target group"
            break
        else
            echo "Waiting for traffic to fully shift..."
            sleep 5
        fi
    done

    # Wait 60 seconds
    sleep 60

    # Shutdown the Green EC2 instance
    echo "Shutting down Green EC2 instance: $GreenEC2"
    aws ec2 stop-instances --instance-ids $GreenEC2

elif [[ "$OncomingLiveStack" == "Green" ]]; then
    # Route 100% traffic to Green for example.com
    aws elbv2 modify-rule --rule-arn $ApplicationLoadBalancer \
        --conditions Field=host-header,Values=example.com \
        --actions Type=forward,TargetGroupArn=$GreenTargetGroup,Weight=100

    echo "Routing 100% of traffic to the Green target group for example.com"
    
    # Confirm that 100% of traffic is routed to Green
    while : ; do
        newRules=$(aws elbv2 describe-rules --listener-arn $ApplicationLoadBalancer)
        newGreenWeight=$(echo $newRules | jq --arg tg "$GreenTargetGroup" '.Rules[].Actions[] | select(.TargetGroupArn == $tg) | .Weight')
        if [[ "$newGreenWeight" -eq 100 ]]; then
            echo "Confirmed: 100% of traffic is now routed to the Green target group"
            break
        else
            echo "Waiting for traffic to fully shift..."
            sleep 5
        fi
    done

    # Wait 60 seconds
    sleep 60

    # Shutdown the Blue EC2 instance
    echo "Shutting down Blue EC2 instance: $BlueEC2"
    aws ec2 stop-instances --instance-ids $BlueEC2

else
    echo "Invalid stack determined. No Production traffic affected, no EC2 instance shutdown."
fi
