# Variables
$ApplicationLoadBalancer = "arn:aws:elasticloadbalancing:region:account-id:loadbalancer/app/my-load-balancer/id"
$BlueTargetGroup = "arn:aws:elasticloadbalancing:region:account-id:targetgroup/blue-target-group/id"
$GreenTargetGroup = "arn:aws:elasticloadbalancing:region:account-id:targetgroup/green-target-group/id"

# Get listener rules for test.example.com
$rules = aws elbv2 describe-rules --listener-arn $ApplicationLoadBalancer | ConvertFrom-Json

# Determine the traffic distribution for test.example.com
$BlueWeight = ($rules.Rules.Actions | Where-Object { $_.TargetGroupArn -eq $BlueTargetGroup }).Weight
$GreenWeight = ($rules.Rules.Actions | Where-Object { $_.TargetGroupArn -eq $GreenTargetGroup }).Weight

# Determine the OncomingLiveStack based on test.example.com traffic
if ($BlueWeight -eq 100) {
    $OncomingLiveStack = "Blue"
} elseif ($GreenWeight -eq 100) {
    $OncomingLiveStack = "Green"
} else {
    Write-Host "Both target groups are receiving traffic for test.example.com - manual resolution required."
    exit 1
}

# Start Canary Deployment: Shift 5% traffic to the OncomingLiveStack
if ($OncomingLiveStack -eq "Blue") {
    aws elbv2 modify-rule --rule-arn $ApplicationLoadBalancer `
        --conditions Field=host-header,Values="example.com" `
        --actions Type=forward,TargetGroupArn=$BlueTargetGroup,Weight=5

    Write-Host "5% of traffic directed to Blue target group for example.com"
    
} elseif ($OncomingLiveStack -eq "Green") {
    aws elbv2 modify-rule --rule-arn $ApplicationLoadBalancer `
        --conditions Field=host-header,Values="example.com" `
        --actions Type=forward,TargetGroupArn=$GreenTargetGroup,Weight=5

    Write-Host "5% of traffic directed to Green target group for example.com"
}

# Gradually increase the traffic to OncomingLiveStack by 5% every 30 seconds, until it reaches 25%
$currentWeight = 5
while ($currentWeight -lt 25) {
    Start-Sleep -Seconds 30
    $currentWeight += 5

    if ($OncomingLiveStack -eq "Blue") {
        aws elbv2 modify-rule --rule-arn $ApplicationLoadBalancer `
            --conditions Field=host-header,Values="example.com" `
            --actions Type=forward,TargetGroupArn=$BlueTargetGroup,Weight=$currentWeight

        Write-Host "Increased traffic to Blue target group to $currentWeight%"
        
    } elseif ($OncomingLiveStack -eq "Green") {
        aws elbv2 modify-rule --rule-arn $ApplicationLoadBalancer `
            --conditions Field=host-header,Values="example.com" `
            --actions Type=forward,TargetGroupArn=$GreenTargetGroup,Weight=$currentWeight

        Write-Host "Increased traffic to Green target group to $currentWeight%"
    }
}
