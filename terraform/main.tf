module "vpc" {
  source = "./modules/vpc"

  vpc_cidr     = var.vpc_cidr
  cluster_name = var.cluster_name
  region       = var.region
}

module "eks" {
  source = "./modules/eks"

  cluster_name = var.cluster_name
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnets
}

module "rds" {
  source = "./modules/rds"

  cluster_name          = var.cluster_name
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnets
  eks_security_group_id = module.eks.cluster_security_group_id
  db_password           = var.db_password
}

module "s3" {
  source = "./modules/s3"

  bucket_name = "${var.cluster_name}-media-storage"
}

module "ecr" {
  source = "./modules/ecr"

  repository_names = [
    "user-service",
    "property-service",
    "booking-service",
    "payment-service",
    "notification-service",
    "reclamation-service",
    "api-gateway",
    "frontend",
    "ai-service"
  ]
}
