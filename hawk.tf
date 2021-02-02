provider "aws" {
  region                  = "us-west-2"
  shared_credentials_file = "/home/rahul-optit/.aws/credentials"
  profile                 = "nonprodqa"
}
resource "aws_launch_template" "hawklaunchtemplate" {
  name = "hawklaunchtemplatetf"

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = 30
      volume_type = "gp2"

    }
  }
  iam_instance_profile {
    name = "nonprodqa-iam-instance-profile"
  }

  image_id = "ami-0d599be3961a582b0"
  key_name = "nonprodqa"

  network_interfaces {
    associate_public_ip_address = false
    subnet_id                   = "subnet-63443d05"
    security_groups             = ["sg-7cefc601"]
  }

  placement {
    availability_zone = "us-west-2a"
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "hawk"
    }
  }
}
resource "aws_spot_fleet_request" "cheap_compute" {
  iam_fleet_role      = "arn:aws:iam::189675173661:role/aws-ec2-spot-fleet-tagging-role"
  spot_price          = "0.03"
  allocation_strategy = "lowestPrice"
  target_capacity     = 1
  valid_until         = "2023-11-04T20:44:20Z"

  launch_specification {
    instance_type        = "m4.10xlarge"
    ami                  = "ami-0d599be3961a582b0"
    key_name             = "nonprodqa"
    spot_price           = "0.366"
    placement_tenancy    = "default"
    iam_instance_profile = "nonprodqa-iam-instance-profile"
    availability_zone    = "us-west-2a"
    subnet_id            = "subnet-63443d05"
    user_data            = "${base64encode(file("hawkud.sh"))}"

  }
  launch_specification {
    instance_type        = "m4.xlarge"
    ami                  = "ami-0d599be3961a582b0"
    key_name             = "nonprodqa"
    spot_price           = "0.366"
    placement_tenancy    = "default"
    iam_instance_profile = "nonprodqa-iam-instance-profile"
    availability_zone    = "us-west-2a"
    subnet_id            = "subnet-63443d05"
    user_data            = "${base64encode(file("hawkud.sh"))}"

  }
  launch_specification {
    instance_type        = "m4.2xlarge"
    ami                  = "ami-0d599be3961a582b0"
    key_name             = "nonprodqa"
    spot_price           = "0.366"
    placement_tenancy    = "default"
    iam_instance_profile = "nonprodqa-iam-instance-profile"
    availability_zone    = "us-west-2a"
    subnet_id            = "subnet-63443d05"
    user_data            = "${base64encode(file("hawkud.sh"))}"

  }

  launch_specification {
    instance_type        = "m4.4xlarge"
    ami                  = "ami-0d599be3961a582b0"
    key_name             = "nonprodqa"
    spot_price           = "0.366"
    placement_tenancy    = "default"
    iam_instance_profile = "nonprodqa-iam-instance-profile"
    availability_zone    = "us-west-2a"
    subnet_id            = "subnet-63443d05"
    user_data            = "${base64encode(file("hawkud.sh"))}"

    tags = {
      Name = "hawk"
    }
  }
}
