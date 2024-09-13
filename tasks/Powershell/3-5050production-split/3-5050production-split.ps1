# Variables
$ApplicationLoadBalancer = "arn:aws:elasticloadbalancing:region:account-id:loadbalancer/app/my-load-balancer/id"
$BlueTargetGroup = "arn:aws:elasticloadbalancing:region:account-id:targetgroup/blue-target-group/id"
$GreenTargetGroup = "arn:aws:elasticloadbalancing:region:account-id:targetgroup/green-target-group/id"
$DNSName = "example.com"

# Modify the rule to split traffic 50% to Blue and 50% to Green
aws elbv2 modify-rule --rule-arn $ApplicationLoadBalancer `
    --conditions Field=host-header,Values=$DNSName `
    --actions Type=forward,TargetGroupArn=$BlueTargetGroup,Weight=50 `
               Type=forward,TargetGroupArn=$GreenTargetGroup,Weight=50

Write-Host "Traffic split: 50% to Blue and 50% to Green"
