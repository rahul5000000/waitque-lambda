#/bin/sh

cd ../lambda
npm run build

cd ../infra
terraform apply