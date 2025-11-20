# PowerShell script to launch an EC2 instance with AWS CLI and attach IAM role + security group.
# Usage: Fill in the variables below, then run in PowerShell after aws cli is configured.

$KeyName = "my-keypair"
$AmiId = "ami-0c02fb55956c7d316" # Amazon Linux 2 (example) - change per region
$InstanceType = "t2.micro" # cheap, free-tier eligible
$SecurityGroup = "sg-0123456789abcdef0"
$SubnetId = "subnet-0123456789abcdef0" # optional
$IamInstanceProfile = "MyEC2DynamoDBRole"
$AwsAccessKey = "" # Optional: if you have an access key & secret from CSV, set them here
$AwsSecret = ""    # Optional: e.g. $AwsAccessKey = "AKIA..."; $AwsSecret = "abc..."
$UserDataFile = "deploy/cloud-init.sh"
$Count = 1

# Create the run-instances command
# If you provide access key and secret, replace placeholders in the user-data file before use.
if ($AwsAccessKey -and $AwsSecret) {
    $userData = Get-Content $UserDataFile -Raw
    $userData = $userData -replace '\$AWS_ACCESS_KEY_ID', $AwsAccessKey
    $userData = $userData -replace '\$AWS_SECRET_ACCESS_KEY', $AwsSecret
    $tempUserData = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tempUserData -Value $userData -Force
    $UserDataToUse = $tempUserData
} else {
    $UserDataToUse = $UserDataFile
}

# Build command arguments — include IAM instance profile only if specified.
$args = @('ec2','run-instances', '--image-id',$AmiId, '--count',$Count, '--instance-type',$InstanceType, '--key-name',$KeyName, '--security-group-ids',$SecurityGroup, '--user-data','file://' + $UserDataToUse)

if ($IamInstanceProfile) {
    $args += @('--iam-instance-profile','Name=' + $IamInstanceProfile)
}

Start-Process -NoNewWindow -FilePath aws -ArgumentList $args -Wait

Write-Host "Instance creation requested. Check AWS console or use 'aws ec2 describe-instances' to follow progress."