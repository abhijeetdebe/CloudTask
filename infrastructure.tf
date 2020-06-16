#Providing the Service Provider name Region and Profile of the user
provider "aws" {
  region = "ap-south-1"
  profile = "abhijeet"
}

#Launching the EC2 Instance
resource "aws_instance" "launch_instance" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "mykey2"
  security_groups = [ "httpsg" ]

  #Connecting to the Instance through ssh for setting up the Requirement
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/HP/Desktop/AWS/mykey2.pem")
    host     = aws_instance.launch_instance.public_ip
  }
  
  #Commands to be runned for setting up our Requirements by remote execution
  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
      "sudo yum install git -y"
    ]
  }
  #Giving the Unique name or Tag to the instance
  tags = {
    Name = "Instance1"
  }

}

# Now Creating the EBS Volume
resource "aws_ebs_volume" "ebs_volume" {

# We want that when instance is created then volume be created 
depends_on = [
    aws_instance.launch_instance,
  ]

#Mentioning the size, region name, and tagging the volume 
  availability_zone = aws_instance.launch_instance.availability_zone
  size              = 1
  tags = {
    Name = "Ebs1"
  }
}

# Attaching the EBS volume to the EC2 Instance
resource "aws_volume_attachment" "attaching_ebs" {

# We that after the volume is created it should be attached
depends_on = [
    aws_ebs_volume.ebs_volume,
  ]

/* Mentioning the name, volume id, instance id where it is to be attach
   Also when we destroy the volume should be detach thats why we do
   Force detach 
*/

  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebs_volume.id
  instance_id = aws_instance.launch_instance.id
  force_detach = true
}

# Formating and Mounting the EBS volume 
resource "null_resource" "format_mount"  {

# Now after we attach we want to partition the volume
depends_on = [
    aws_volume_attachment.attaching_ebs,
  ]

# For running the commands we connect to the Instance through ssh 
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/HP/Desktop/AWS/mykey2.pem")
    host     = aws_instance.launch_instance.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/abhijeetdebe/CloudTask.git /var/www/html/"
    ]
  }
}

#S3

resource "aws_s3_bucket" "debebucket" {

depends_on = [
    null_resource.format_mount,
  ]

  bucket = "debebucket"
  acl   = "public-read"
  region = "ap-south-1"
  force_destroy = true

  tags = {
    Name        = "debeBucket"
  }
}

resource "aws_s3_bucket_object" "debeobject" {

depends_on = [
    aws_s3_bucket.debebucket,
  ]

  bucket = aws_s3_bucket.debebucket.id
  key    = "cloudImage"
  source = "C:/Users/HP/Desktop/tera/cloudautomation/cloud.jpg"
  acl   = "public-read"
  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag = filemd5("C:/Users/HP/Desktop/tera/cloudautomation/cloud.jpg")
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "debe_public_access_block" {
depends_on = [
    aws_s3_bucket_object.debeobject,
  ]
 

 bucket = aws_s3_bucket.debebucket.id
  block_public_acls   = false
  block_public_policy = false
}

#Now Requesting the html Page
resource "null_resource" "requesting"  {

depends_on = [
    aws_s3_bucket_public_access_block.debe_public_access_block,
  ]

	provisioner "local-exec" {
	    command = "chrome  ${aws_instance.launch_instance.public_ip}"
  	}
}