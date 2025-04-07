module "vpc" {
  source              = "./modules/vpc"
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones  = var.availability_zones
  vpc_name            = var.vpc_name
}

module "iam" {
  source        = "./modules/iam"
  iam_role_name = var.iam_role_name
}

module "eks" {
  source               = "./modules/eks"
  cluster_name         = var.cluster_name
  vpc_id               = module.vpc.vpc_id
  private_subnets      = module.vpc.private_subnet_ids
  public_subnets       = module.vpc.public_subnet_ids
  eks_role_arn         = module.iam.eks_role_arn
  worker_role_arn      = module.iam.worker_role_arn
  node_instance_type   = var.node_instance_type
  desired_capacity     = var.desired_capacity
  min_size             = var.min_size
  max_size             = var.max_size 
  worker_security_group_ids = [module.vpc.worker_sg_id] 
  lb_sg_id              = module.vpc.lb_sg_id
}







