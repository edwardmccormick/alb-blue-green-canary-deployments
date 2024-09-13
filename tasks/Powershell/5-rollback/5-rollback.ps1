# Variables
$ApplicationLoadBalancer = "arn:aws:elasticloadbalancing:region:account-id:loadbalancer/app/my-load-balancer/id"
$BlueTargetGroup = "arn:aws:elasticloadbalancing:region:account-id:targetgroup/blue-target-group/id"
$GreenTargetGroup = "arn:aws:elasticloadbalancing:region:account-id:targetgroup/green-target-group/id"

# Get listener rules for example.com and test.example.com
$rules = aws elbv2 describe-rules --listener-arn $ApplicationLoadBalancer | ConvertFrom-Json

# Determine the traffic weights for example.com
$exampleBlueWeight = ($rules.Rules.Actions | Where-Object { $_.TargetGroupArn -eq $BlueTargetGroup }).Weight
$exampleGreenWeight = ($rules.Rules.Actions | Where-Object { $_.TargetGroupArn -eq $GreenTargetGroup }).Weight

# Determine the traffic weights for test.example.com
$testBlueWeight = ($rules.Rules.Actions | Where-Object { $_.TargetGroupArn -eq $BlueTargetGroup }).Weight
$testGreenWeight = ($rules.Rules.Actions | Where-Object { $_.TargetGroupArn -eq $GreenTargetGroup }).Weight

# Write current traffic weights
Write-Host "Current traffic weights for example.com:"
Write-Host "Blue Target Group: $exampleBlueWeight"
Write-Host "Green Target Group: $exampleGreenWeight"
Write-Host ""
Write-Host "Current traffic weights for test.example.com:"
Write-Host "Blue Target Group: $testBlueWeight"
Write-Host "Green Target Group: $testGreenWeight"

# Determine which target group is receiving 100% of the traffic for test.example.com
if ($testBlueWeight -eq 100) {
    $TargetGroupToRedirect = $GreenTargetGroup
    Write-Host "Traffic for test.example.com is going to the Blue target group. Redirecting all traffic to the Green target group."
} elseif ($testGreenWeight -eq 100) {
    $TargetGroupToRedirect = $BlueTargetGroup
    Write-Host "Traffic for test.example.com is going to the Green target group. Redirecting all traffic to the Blue target group."
} else {
    Write-Host "Unable to determine correct target group for rollback; manual resolution required!"
    exit 1
}

# Redirect all traffic for example.com and test.example.com to the target group that is not receiving 100% of the traffic from test.example.com
aws elbv2 modify-rule --rule-arn $ApplicationLoadBalancer `
    --conditions Field=host-header,Values="example.com" `
    --actions Type=forward,TargetGroupArn=$TargetGroupToRedirect,Weight=100

aws elbv2 modify-rule --rule-arn $ApplicationLoadBalancer `
    --conditions Field=host-header,Values="test.example.com" `
    --actions Type=forward,TargetGroupArn=$TargetGroupToRedirect,Weight=100

Write-Host "Traffic for example.com and test.example.com now directed to $TargetGroupToRedirect"
