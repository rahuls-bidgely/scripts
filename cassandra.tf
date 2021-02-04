provider "aws" {
  region                  = "us-east-1"
  shared_credentials_file = "/home/rahul-optit/.aws/credentials"
  profile                 = "na"
}

resource "aws_instance" "cassandra" {

  ami                    = "ami-023935cef4f385f2d"
  instance_type          = "m4.2xlarge"
  availability_zone      = "us-east-1a"
  key_name               = "naprod"
  subnet_id              = "subnet-cf1687b8"
  vpc_security_group_ids = ["sg-289a374c", "sg-554e682e", "sg-269a3742", "sg-65d35d03"]
  iam_instance_profile   = "cloudwatchagentadminrole"
  tags = {
    Name = "NACassCluster-1A_RackA_New_1"
  }
}
resource "aws_ebs_volume" "commit-log" {
  availability_zone = "us-east-1a"
  size              = 40
}
resource "aws_volume_attachment" "commit-dir-vol" {
  device_name = "/dev/sdb"
  volume_id   = "${aws_ebs_volume.commit-log.id}"
  instance_id = "${aws_instance.cassandra.id}"
}
resource "aws_ebs_volume" "data-dir" {
  availability_zone = "us-east-1a"
  size              = 1500
}
resource "aws_volume_attachment" "data-dir-vol" {
  device_name = "/dev/sdc"
  volume_id   = "${aws_ebs_volume.data-dir.id}"
  instance_id = "${aws_instance.cassandra.id}"
}
