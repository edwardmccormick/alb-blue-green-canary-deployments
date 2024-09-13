# Variables
$ApplicationLoadBalancer = "arn:aws:elasticloadbalancing:region:account-id:loadbalancer/app/my-load-balancer/id"
$BlueTargetGroup = "arn:aws:elasticloadbalancing:region:account-id:targetgroup/blue-target-group/id"
$GreenTargetGroup = "arn:aws:elasticloadbalancing:region:account-id:targetgroup/green-target-group/id"

# Get listener rules for example.com
$rules = aws elbv2 describe-rules --listener-arn $ApplicationLoadBalancer | ConvertFrom-Json

# Check the traffic distribution
$BlueWeight = ($rules.Rules.Actions | Where-Object { $_.TargetGroupArn -eq $BlueTargetGroup }).Weight
$GreenWeight = ($rules.Rules.Actions | Where-Object { $_.TargetGroupArn -eq $GreenTargetGroup }).Weight

# Ensure 100% traffic is going to one target group
if ($BlueWeight -eq 100) {
    $CurrentLiveStack = "Blue"
} elseif ($GreenWeight -eq 100) {
    $CurrentLiveStack = "Green"
} else {
    Write-Host "Both target groups receiving production traffic - please manually resolve this situation and rerun this pipeline."
    exit 1
}

# Export the variable to Azure DevOps
Write-Host "##vso[task.setvariable variable=CurrentLiveStack]$CurrentLiveStack"
Write-Host "CurrentLiveStack set to $CurrentLiveStack and exported to Azure DevOps"
