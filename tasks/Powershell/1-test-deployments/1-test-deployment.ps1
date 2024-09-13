# Variables
$ApplicationLoadBalancer = "arn:aws:elasticloadbalancing:region:account-id:loadbalancer/app/my-load-balancer/id"
$BlueTargetGroup = "arn:aws:elasticloadbalancing:region:account-id:targetgroup/blue-target-group/id"
$GreenTargetGroup = "arn:aws:elasticloadbalancing:region:account-id:targetgroup/green-target-group/id"

# Get listener rules for example.com and test.example.com
$rules = aws elbv2 describe-rules --listener-arn $ApplicationLoadBalancer | ConvertFrom-Json

# Determine the traffic distribution for example.com and test.example.com
$exampleBlueWeight = ($rules.Rules.Actions | Where-Object { $_.TargetGroupArn -eq $BlueTargetGroup }).Weight
$exampleGreenWeight = ($rules.Rules.Actions | Where-Object { $_.TargetGroupArn -eq $GreenTargetGroup }).Weight

$testBlueWeight = ($rules.Rules.Actions | Where-Object { $_.TargetGroupArn -eq $BlueTargetGroup }).Weight
$testGreenWeight = ($rules.Rules.Actions | Where-Object { $_.TargetGroupArn -eq $GreenTargetGroup }).Weight

# Determine the TargetGroupToReceiveTraffic
if ($exampleBlueWeight -eq 100 -and $testBlueWeight -eq 100) {
    $TargetGroupToReceiveTraffic = $GreenTargetGroup
    Write-Host "Redirecting 100% of traffic for test.example.com to the Green target group"
} elseif ($exampleGreenWeight -eq 100 -and $testGreenWeight -eq 100) {
    $TargetGroupToReceiveTraffic = $BlueTargetGroup
    Write-Host "Redirecting 100% of traffic for test.example.com to the Blue target group"
} else {
    Write-Host "Error - all traffic is not currently going to a single stack. Manual resolution is required before a Blue/Green or Canary deployment can be attempted."
    exit 1
}

# Shift 100% of traffic for test.example.com to the other stack
aws elbv2 modify-rule --rule-arn $ApplicationLoadBalancer `
    --conditions Field=host-header,Values="test.example.com" `
    --actions Type=forward,TargetGroupArn=$TargetGroupToReceiveTraffic,Weight=100

Write-Host "Traffic for test.example.com now directed to $TargetGroupToReceiveTraffic"
