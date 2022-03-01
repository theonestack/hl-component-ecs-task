require 'yaml'

describe 'compiled component' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/ephemeral_storage.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/ephemeral_storage/ecs-task.compiled.yaml") }

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

    it "to have property EphemeralStorage" do
        expect(properties["EphemeralStorage"]).to eq({"SizeInGiB"=>50})
    end

    it 'has property One container definition ' do
      expect(properties["ContainerDefinitions"].count).to eq(1)
      expect(properties["ContainerDefinitions"]).to eq([{
        "Image"=>{"Fn::Join"=>["", [{"Fn::Sub"=>"myrepo/"}, "backend", ":", {"Ref"=>"SchemaTag"}]]},
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
end