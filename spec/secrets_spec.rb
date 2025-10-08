require 'yaml'

describe 'compiled component ecs-task' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/secrets.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/secrets/ecs-task.compiled.yaml") }
  
  context "Resource" do

    
    context "LogGroup" do
      let(:resource) { template["Resources"]["LogGroup"] }

      it "is of type AWS::Logs::LogGroup" do
          expect(resource["Type"]).to eq("AWS::Logs::LogGroup")
      end
      
      it "to have property LogGroupName" do
          expect(resource["Properties"]["LogGroupName"]).to eq({"Ref"=>"AWS::StackName"})
      end
      
      it "to have property RetentionInDays" do
          expect(resource["Properties"]["RetentionInDays"]).to eq(7)
      end
      
    end
    
    context "TaskRole" do
      let(:resource) { template["Resources"]["TaskRole"] }

      it "is of type AWS::IAM::Role" do
          expect(resource["Type"]).to eq("AWS::IAM::Role")
      end
      
      it "to have property AssumeRolePolicyDocument" do
          expect(resource["Properties"]["AssumeRolePolicyDocument"]).to eq({"Version"=>"2012-10-17", "Statement"=>[{"Effect"=>"Allow", "Principal"=>{"Service"=>"ecs-tasks.amazonaws.com"}, "Action"=>"sts:AssumeRole"}, {"Effect"=>"Allow", "Principal"=>{"Service"=>"ssm.amazonaws.com"}, "Action"=>"sts:AssumeRole"}]})
      end
      
      it "to have property Path" do
          expect(resource["Properties"]["Path"]).to eq("/")
      end
      
      it "to have property Policies" do
          expect(resource["Properties"]["Policies"]).to eq([{"PolicyName"=>"s3", "PolicyDocument"=>{"Version"=>"2012-10-17", "Statement"=>[{"Sid"=>"s3", "Action"=>["s3:Get*"], "Resource"=>["*"], "Effect"=>"Allow"}]}}])
      end
      
    end
    
    context "ExecutionRole" do
      let(:resource) { template["Resources"]["ExecutionRole"] }

      it "is of type AWS::IAM::Role" do
          expect(resource["Type"]).to eq("AWS::IAM::Role")
      end
      
      it "to have property AssumeRolePolicyDocument" do
          expect(resource["Properties"]["AssumeRolePolicyDocument"]).to eq({"Version"=>"2012-10-17", "Statement"=>[{"Effect"=>"Allow", "Principal"=>{"Service"=>"ecs-tasks.amazonaws.com"}, "Action"=>"sts:AssumeRole"}, {"Effect"=>"Allow", "Principal"=>{"Service"=>"ssm.amazonaws.com"}, "Action"=>"sts:AssumeRole"}]})
      end
      
      it "to have property Path" do
          expect(resource["Properties"]["Path"]).to eq("/")
      end
      
      it "to have property ManagedPolicyArns" do
          expect(resource["Properties"]["ManagedPolicyArns"]).to eq(["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"])
      end
      
      it "to have property Policies" do
          expect(resource["Properties"]["Policies"]).to eq([{"PolicyName"=>"ssm-secrets-nginx", "PolicyDocument"=>{"Version"=>"2012-10-17", "Statement"=>[{"Sid"=>"ssmsecretsnginx", "Action"=>"ssm:GetParameters", "Resource"=>[{"Fn::Sub"=>"arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/nginx/${EnvironmentName}/app/key"}, {"Fn::Sub"=>"arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/nginx/${EnvironmentName}/app/secret"}], "Effect"=>"Allow"}]}}, {"PolicyName"=>"secretsmanager-nginx", "PolicyDocument"=>{"Version"=>"2012-10-17", "Statement"=>[{"Sid"=>"secretsmanagernginx", "Action"=>"secretsmanager:GetSecretValue", "Resource"=>[{"Fn::Sub"=>"arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:/dont/use/accesskeys-*"}, {"Ref"=>"EnvironmentName"}], "Effect"=>"Allow"}]}}, {"PolicyName"=>"ssm-secrets-inline-nginx", "PolicyDocument"=>{"Version"=>"2012-10-17", "Statement"=>[{"Sid"=>"ssmsecretsinlinenginx", "Action"=>"ssm:GetParameters", "Resource"=>[{"Fn::Sub"=>"arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/nginx/${EnvironmentName}/api/key"}, {"Fn::Sub"=>"arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/nginx/${EnvironmentName}/api/secret"}], "Effect"=>"Allow"}]}}])
      end
      
    end
    
    context "Task" do
      let(:resource) { template["Resources"]["Task"] }

      it "is of type AWS::ECS::TaskDefinition" do
          expect(resource["Type"]).to eq("AWS::ECS::TaskDefinition")
      end
      
      it "to have property ContainerDefinitions" do
          expect(resource["Properties"]["ContainerDefinitions"]).to eq([{"Name"=>"nginx", "Image"=>{"Fn::Join"=>["", [{"Fn::Sub"=>"nginx/nginx"}, ":", "latest"]]}, "LogConfiguration"=>{"LogDriver"=>"awslogs", "Options"=>{"awslogs-group"=>{"Ref"=>"LogGroup"}, "awslogs-region"=>{"Ref"=>"AWS::Region"}, "awslogs-stream-prefix"=>"nginx"}}, "Secrets"=>[{"Name"=>"APP_KEY", "ValueFrom"=>{"Fn::Sub"=>"arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/nginx/${EnvironmentName}/app/key"}}, {"Name"=>"APP_SECRET", "ValueFrom"=>{"Fn::Sub"=>"arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/nginx/${EnvironmentName}/app/secret"}}, {"Name"=>"ACCESSKEY", "ValueFrom"=>{"Fn::Sub"=>"arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:/dont/use/accesskeys"}}, {"Name"=>"SECRETKEY", "ValueFrom"=>{"Ref"=>"EnvironmentName"}}, {"Name"=>"API_KEY", "ValueFrom"=>{"Fn::Sub"=>"arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/nginx/${EnvironmentName}/api/key"}}, {"Name"=>"API_SECRET", "ValueFrom"=>{"Fn::Sub"=>"arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/nginx/${EnvironmentName}/api/secret"}}]}])
      end
      
      it "to have property RequiresCompatibilities" do
          expect(resource["Properties"]["RequiresCompatibilities"]).to eq(["EC2"])
      end
      
      it "to have property TaskRoleArn" do
          expect(resource["Properties"]["TaskRoleArn"]).to eq({"Ref"=>"TaskRole"})
      end
      
      it "to have property ExecutionRoleArn" do
          expect(resource["Properties"]["ExecutionRoleArn"]).to eq({"Ref"=>"ExecutionRole"})
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}])
      end
      
    end
    
  end

end