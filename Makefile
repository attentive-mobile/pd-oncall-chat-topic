STACKNAME_BASE=attentive-pagerduty-oncall-chat-topic
REGION="us-east-1"
# Bucket in REGION that is used for deployment (`pd-oncall-chat-topic` is already used)
BUCKET=$(STACKNAME_BASE)
SSMKeyArn=$(shell aws kms --region $(REGION) describe-key --key-id alias/aws/ssm --query KeyMetadata.Arn)
MD5=$(shell md5sum lambda/*.py | md5sum | cut -d ' ' -f 1)

deployment.zip: lambda/main.py
	rm -rf ./lambda-deps
	mkdir ./lambda-deps
	pip3 install --target ./lambda-deps requests
	cd ./lambda-deps && zip -r9 ../deployment.zip .
	cd lambda && zip -g ../deployment.zip *.py

deploy: deployment.zip
	aws s3 cp --region $(REGION) $^ s3://$(BUCKET)/$(MD5)
	aws cloudformation deploy \
		--template-file deployment.yml \
		--stack-name $(STACKNAME_BASE) \
		--region $(REGION) \
		--parameter-overrides \
		"Bucket=$(BUCKET)" \
		"md5=$(MD5)" \
		"SSMKeyArn"=$(SSMKeyArn) \
		"PDSSMKeyName"=$(STACKNAME_BASE) \
		"SlackSSMKeyName"=$(STACKNAME_BASE)-slack \
		--capabilities CAPABILITY_IAM

discover:
	aws cloudformation --region $(REGION) \
		describe-stacks \
		--stack-name $(STACKNAME_BASE) \
		--query 'Stacks[0].Outputs'

put-pd-key:
	./scripts/put-ssm.sh $(STACKNAME_BASE) $(STACKNAME_BASE) $(REGION)

put-slack-key:
	./scripts/put-ssm.sh $(STACKNAME_BASE)-slack $(STACKNAME_BASE) $(REGION)