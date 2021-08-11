require 'yaml'

describe 'compiled component' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/secrets.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/secrets/ecs-task.compiled.yaml") }

  context 'Resource Task' do
    let(:properties) { template["Resources"]["Task"]["Properties"] }

    it 'has property RequiresCompatibilities ' do
      expect(properties["RequiresCompatibilities"]).to eq(['EC2'])
    end
    
    it 'has property NetworkMode ' do
      expect(properties["NetworkMode"]).to eq(nil)
    end

    it 'has property CPU ' do
      expect(properties["Cpu"]).to eq(nil)
    end

    it 'has property Memory ' do
      expect(properties["Memory"]).to eq(nil)
    end

    it 'has property One container definition ' do
      expect(properties["ContainerDefinitions"].count).to eq(1)
      expect(properties["ContainerDefinitions"]).to eq([{
        "Name"=>"nginx",
        "Image"=>{"Fn::Join"=>["", [{"Fn::Sub"=>"nginx/"}, "nginx", ":", "latest"]]},
        "LogConfiguration"=> {
              "LogDriver"=>"awslogs",
              "Options"=> {
                "awslogs-group"=>{"Ref"=>"LogGroup"},
                "awslogs-region"=>{"Ref"=>"AWS::Region"},
                "awslogs-stream-prefix"=>"nginx"
              }
        },
        "Secrets"=> [
          {
            "Name"=>"APP_KEY",
            "ValueFrom" => { 
              "Fn::Sub" => "arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/nginx/${EnvironmentName}/app/key"
            }
          },
          {
            "Name"=>"APP_SECRET",
            "ValueFrom" => {
              "Fn::Sub" => "arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/nginx/${EnvironmentName}/app/secret"
            }
          },
          {
            "Name"=>"ACCESSKEY",
            "ValueFrom" => {
              "Fn::Sub" => "arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:/dont/use/accesskeys"
            }
          },
          {"Name"=>"SECRETKEY", "ValueFrom"=>{"Ref"=>"EnvironmentName"}},
          {
            "Name"=>"API_KEY",
            "ValueFrom" => {
              "Fn::Sub" => "arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/nginx/${EnvironmentName}/api/key"
            }
          },
          {
            "Name"=>"API_SECRET",
            "ValueFrom" => {
              "Fn::Sub" => "arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/nginx/${EnvironmentName}/api/secret"
            }
          }
        ]
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

  context 'Resource TaskRole' do
    let(:properties) { template["Resources"]["TaskRole"]["Properties"] }

    it 'has Task Role' do
      expect(properties).to eq({
        "AssumeRolePolicyDocument" => {"Statement"=>[{"Action"=>"sts:AssumeRole", "Effect"=>"Allow", "Principal"=>{"Service"=>"ecs-tasks.amazonaws.com"}}, {"Action"=>"sts:AssumeRole", "Effect"=>"Allow", "Principal"=>{"Service"=>"ssm.amazonaws.com"}}], "Version"=>"2012-10-17"},
        "Path" => "/",
        "Policies" => [{"PolicyDocument"=>{"Statement"=>[{"Action"=>["s3:Get*"], "Effect"=>"Allow", "Resource"=>["*"], "Sid"=>"s3"}]}, "PolicyName"=>"s3"}],        
      })
      end
  end

  context 'Resource Execution Role' do
    let(:properties) { template["Resources"]["ExecutionRole"]["Properties"] }

    it 'has Execution Role' do
      expect(properties).to eq({
        "AssumeRolePolicyDocument" => {
          "Statement"=>[
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
          "Version"=>"2012-10-17"
        },
        "ManagedPolicyArns" => ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"],
        "Path" => "/",
        "Policies" => [
          {
            "PolicyName"=>"ssm-secrets",
            "PolicyDocument"=>{
              "Statement"=>[
                {
                  "Action"=>"ssm:GetParameters",
                  "Effect"=>"Allow",
                  "Resource"=>[
                    {"Fn::Sub"=>"arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/nginx/${EnvironmentName}/app/key"},
                    {"Fn::Sub"=>"arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/nginx/${EnvironmentName}/app/secret"}
                  ], 
                  "Sid"=>"ssmsecrets"
                }
              ]
            } 
          }, 
          {
            "PolicyName"=>"secretsmanager",
            "PolicyDocument"=>{
              "Statement"=>[
                {"Action"=>"secretsmanager:GetSecretValue",
                "Effect"=>"Allow",
                "Resource"=>[
                  {"Fn::Sub"=>"arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:/dont/use/accesskeys-*"},
                  {"Ref"=>"EnvironmentName"}
                ],
                "Sid"=>"secretsmanager"}
              ]
            }
          },
          {
            "PolicyName"=>"ssm-secrets-inline",
            "PolicyDocument"=>{
              "Statement"=>[
                {"Action"=>"ssm:GetParameters",
                "Effect"=>"Allow",
                "Resource"=>[
                  {"Fn::Sub"=>"arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/nginx/${EnvironmentName}/api/key"},
                  {"Fn::Sub"=>"arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter/nginx/${EnvironmentName}/api/secret"}
                ],
                "Sid"=>"ssmsecretsinline"}
              ]
            }
          }
        ]
      })
      end
  end
end