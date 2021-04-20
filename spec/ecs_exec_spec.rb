require 'yaml'

describe 'compiled component' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/ecs-exec.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/ecs-exec/ecs-task.compiled.yaml") }

  context 'Resource Task' do
    let(:properties) { template["Resources"]["Task"]["Properties"] }

    it 'has property RequiresCompatibilities ' do
      expect(properties["RequiresCompatibilities"]).to eq(['FARGATE'])
    end
    
    it 'has property NetworkMode ' do
      expect(properties["NetworkMode"]).to eq('awsvpc')
    end

    it 'has property CPU ' do
      expect(properties["Cpu"]).to eq(256)
    end

    it 'has property Memory ' do
      expect(properties["Memory"]).to eq(512)
    end

    it 'has property One container definition ' do
      expect(properties["ContainerDefinitions"].count).to eq(1)
      expect(properties["ContainerDefinitions"]).to eq([{
        "Image"=>{"Fn::Join"=>["", ["myrepo/", "backend", ":", {"Ref"=>"SchemaTag"}]]},
        "LogConfiguration"=>
            {
              "LogDriver"=>"awslogs",
              "Options"=> {
                "awslogs-group"=>{"Ref"=>"LogGroup"},
                "awslogs-region"=>{"Ref"=>"AWS::Region"},
                "awslogs-stream-prefix"=>"schema"
              }
            },
        "Name"=>"schema"
      }])
    end

    it 'has property Tags' do
      expect(properties["Tags"]).to eq([
        {"Key"=>"Name", "Value"=>"ecs-task"}, 
        {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, 
        {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}
      ])
    end
  end

  context 'Task Role' do
    let(:properties) { template["Resources"]["TaskRole"]["Properties"] }

    it 'has ecs-tasks assume role permissions' do
      expect(properties["AssumeRolePolicyDocument"]).to eq({
        "Version" => "2012-10-17",
        "Statement" => [
          {
            "Action"=>"sts:AssumeRole",
            "Effect"=>"Allow",
            "Principal"=>{"Service"=>"ecs-tasks.amazonaws.com"}
          },
          {
            "Action"=>"sts:AssumeRole", 
            "Effect"=>"Allow", 
            "Principal"=>{"Service"=>"ssm.amazonaws.com"}
          }
        ],
      })
    end

    it 'has SSM IAM Policies' do
      expect(properties["Policies"]).to eq([
        "PolicyName" => "ssm-session-manager",
        "PolicyDocument" => {
          "Statement" => [{
            "Sid" => "ssmsessionmanager",
            "Effect" => "Allow",
            "Action" => [
              "ssmmessages:CreateControlChannel",
              "ssmmessages:CreateDataChannel",
              "ssmmessages:OpenControlChannel",
              "ssmmessages:OpenDataChannel"
            ],
            "Resource" => ["*"],
          }]
        }
      ])
    end
  end
end