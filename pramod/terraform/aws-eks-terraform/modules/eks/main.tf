resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.eks_role_arn
  version  = "1.32" 

  vpc_config {
    subnet_ids = var.public_subnets
    security_group_ids = var.worker_security_group_ids
  }
}

resource "aws_eks_node_group" "this" {
  depends_on      = [aws_eks_cluster.this]
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = var.worker_role_arn   
  subnet_ids      = var.private_subnets   

  scaling_config {
    desired_size = var.desired_capacity
    min_size     = var.min_size
    max_size     = var.max_size
  }

  instance_types = [var.node_instance_type]
}

output "cluster_name" {
  value = aws_eks_cluster.this.name
}


#########################
# Load Balancer configs
#########################


# resource "aws_lb" "app_lb" {
#   name               = "eks-lb"
#   load_balancer_type = "application"
#   internal           = false
#   security_groups    = [var.lb_sg_id] 
#   subnets            = var.public_subnets

#   enable_deletion_protection = false

#   tags = {
#     Name = "eks-lb"
#   }
# }

# resource "aws_lb_target_group" "eks-lb-tg" {
#   name     = "eks-lb-target-group"
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = var.vpc_id

#   health_check {
#     path                = "/"
#     protocol            = "HTTP"
#     interval            = 30
#     timeout             = 5
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#   }

#   tags = {
#     Name = "eks-lb-tg"
#   }
# }

# resource "aws_lb_listener" "http" {
#   load_balancer_arn = aws_lb.app_lb.arn
#   port              = 80
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.eks-lb-tg.arn
#   }
# }

# output "lb-endpoints" {
#   value = aws_lb.app_lb
  
# }

