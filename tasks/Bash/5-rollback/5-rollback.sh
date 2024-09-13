#!/bin/bash

# Variables
ApplicationLoadBalancer="arn:aws:elasticloadbalancing:region:account-id:loadbalancer/app/my-load-balancer/id"
BlueTargetGroup="arn:aws:elasticloadbalancing:region:account-id:targetgroup/blue-target-group/id"
GreenTargetGroup="arn:aws:elasticloadbalancing:region:account-id:targetgroup/green-target-group/id"

# Get listener rules for example.com and test.example.com
rules=$(aws elbv2 describe-rules --listener-arn $ApplicationLoadBalancer)

# Determine the traffic weights for example.com
exampleBlueWeight=$(echo $rules | jq --arg tg "$BlueTargetGroup" '.Rules[].Actions[] | select(.TargetGroupArn == $tg) | .Weight')
exampleGreenWeight=$(echo $rules | jq --arg tg "$GreenTargetGroup" '.Rules[].Actions[] | select(.TargetGroupArn == $tg) | .Weight')

# Determine the traffic weights for test.example.com
testBlueWeight=$(echo $rules | jq --arg tg "$BlueTargetGroup" '.Rules[].Actions[] | select(.TargetGroupArn == $tg) | .Weight')
testGreenWeight=$(echo $rules | jq --arg tg "$GreenTargetGroup" '.Rules[].Actions[] | select(.TargetGroupArn == $tg) | .Weight')

# Echo current traffic weights
echo "Current traffic weights for example.com:"
echo "Blue Target Group: $exampleBlueWeight"
echo "Green Target Group: $exampleGreenWeight"
echo ""
echo "Current traffic weights for test.example.com:"
echo "Blue Target Group: $testBlueWeight"
echo "Green Target Group: $testGreenWeight"

# Determine which target group is receiving 100% of the traffic for test.example.com
if [[ "$testBlueWeight" -eq 100 ]]; then
    TargetGroupToRedirect=$GreenTargetGroup
    echo "Traffic for test.example.com is going to the Blue target group. Redirecting all traffic to the Green target group."
elif [[ "$testGreenWeight" -eq 100 ]]; then
    TargetGroupToRedirect=$BlueTargetGroup
    echo "Traffic for test.example.com is going to the Green target group. Redirecting all traffic to the Blue target group."
else
    echo "Unable to determine correct target group for rollback; manual resolution required!"
    exit 1
fi

# Redirect all traffic for example.com and test.example.com to the target group that is not receiving 100% of the traffic from test.example.com
aws elbv2 modify-rule --rule-arn $ApplicationLoadBalancer \
    --conditions Field=host-header,Values=example.com \
    --actions Type=forward,TargetGroupArn=$TargetGroupToRedirect,Weight=100

aws elbv2 modify-rule --rule-arn $ApplicationLoadBalancer \
    --conditions Field=host-header,Values=test.example.com \
    --actions Type=forward,TargetGroupArn=$TargetGroupToRedirect,Weight=100

echo "Traffic for example.com and test.example.com now directed to $TargetGroupToRedirect"
