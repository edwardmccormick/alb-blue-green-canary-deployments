# Variables
$ApplicationLoadBalancer = "arn:aws:elasticloadbalancing:region:account-id:loadbalancer/app/my-load-balancer/id"
$BlueTargetGroup = "arn:aws:elasticloadbalancing:region:account-id:targetgroup/blue-target-group/id"
$GreenTargetGroup = "arn:aws:elasticloadbalancing:region:account-id:targetgroup/green-target-group/id"
$BlueEC2 = "i-0123456789abcdef0" # EC2 instance ID for Blue
$GreenEC2 = "i-0123456789abcdef1" # EC2 instance ID for Green

# Get listener rules for test.example.com
$rules = aws elbv2 describe-rules --listener-arn $ApplicationLoadBalancer | ConvertFrom-Json

# Check the traffic distribution for test.example.com
$BlueWeight = ($rules.Rules.Actions | Where-Object { $_.TargetGroupArn -eq $BlueTargetGroup }).Weight
$GreenWeight = ($rules.Rules.Actions | Where-Object { $_.TargetGroupArn -eq $GreenTargetGroup }).Weight

# Determine the OncomingLiveStack
if ($BlueWeight -eq 100) {
    $OncomingLiveStack = "Blue"
} elseif ($GreenWeight -eq 100) {
    $OncomingLiveStack = "Green"
} else {
    Write-Host "Both target groups are receiving traffic for test.example.com - manual resolution required."
    exit 1
}

# Route 100% of traffic to the same target group for example.com as test.example.com
if ($OncomingLiveStack -eq "Blue") {
    # Route 100% traffic to Blue for example.com
    aws elbv2 modify-rule --rule-arn $ApplicationLoadBalancer `
        --conditions Field=host-header,Values="example.com" `
        --actions Type=forward,TargetGroupArn=$BlueTargetGroup,Weight=100

    Write-Host "Routing 100% of traffic to the Blue target group for example.com"
    
    # Confirm that 100% of traffic is routed to Blue
    do {
        $newRules = aws elbv2 describe-rules --listener-arn $ApplicationLoadBalancer | ConvertFrom-Json
        $newBlueWeight = ($newRules.Rules.Actions | Where-Object { $_.TargetGroupArn -eq $BlueTargetGroup }).Weight
        if ($newBlueWeight -eq 100) {
            Write-Host "Confirmed: 100% of traffic is now routed to the Blue target group"
            break
        } else {
            Write-Host "Waiting for traffic to fully shift..."
            Start-Sleep -Seconds 5
        }
    } while ($true)

    # Wait 60 seconds
    Start-Sleep -Seconds 60

    # Shutdown the Green EC2 instance
    Write-Host "Shutting down Green EC2 instance: $GreenEC2"
    aws ec2 stop-instances --instance-ids $GreenEC2

} elseif ($OncomingLiveStack -eq "Green") {
    # Route 100% traffic to Green for example.com
    aws elbv2 modify-rule --rule-arn $ApplicationLoadBalancer `
        --conditions Field=host-header,Values="example.com" `
        --actions Type=forward,TargetGroupArn=$GreenTargetGroup,Weight=100

    Write-Host "Routing 100% of traffic to the Green target group for example.com"
    
    # Confirm that 100% of traffic is routed to Green
    do {
        $newRules = aws elbv2 describe-rules --listener-arn $ApplicationLoadBalancer | ConvertFrom-Json
        $newGreenWeight = ($newRules.Rules.Actions | Where-Object { $_.TargetGroupArn -eq $GreenTargetGroup }).Weight
        if ($newGreenWeight -eq 100) {
            Write-Host "Confirmed: 100% of traffic is now routed to the Green target group"
            break
        } else {
            Write-Host "Waiting for traffic to fully shift..."
            Start-Sleep -Seconds 5
        }
    } while ($true)

    # Wait 60 seconds
    Start-Sleep -Seconds 60

    # Shutdown the Blue EC2 instance
    Write-Host "Shutting down Blue EC2 instance: $BlueEC2"
    aws ec2 stop-instances --instance-ids $BlueEC2

} else {
    Write-Host "Invalid stack determined. No EC2 instance shutdown."
}
