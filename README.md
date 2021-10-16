export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=

cd infra/state
terraform init
terraform apply
cd ../site
terraform init
terraform apply

upload files