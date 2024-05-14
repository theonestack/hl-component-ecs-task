require 'yaml'

describe 'compiled component ecs-task' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/ec2.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/ec2/ecs-task.compiled.yaml") }
  
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
    
    context "Task" do
      let(:resource) { template["Resources"]["Task"] }

      it "is of type AWS::ECS::TaskDefinition" do
          expect(resource["Type"]).to eq("AWS::ECS::TaskDefinition")
      end
      
      it "to have property ContainerDefinitions" do
          expect(resource["Properties"]["ContainerDefinitions"]).to eq([{"Name"=>"schema", "Image"=>{"Fn::Join"=>["", [{"Fn::Sub"=>"myrepo/backend"}, ":", {"Ref"=>"SchemaTag"}]]}, "LogConfiguration"=>{"LogDriver"=>"awslogs", "Options"=>{"awslogs-group"=>{"Ref"=>"LogGroup"}, "awslogs-region"=>{"Ref"=>"AWS::Region"}, "awslogs-stream-prefix"=>"schema"}}}])
      end
      
      it "to have property RequiresCompatibilities" do
          expect(resource["Properties"]["RequiresCompatibilities"]).to eq(["EC2"])
      end
      
      it "to have property Tags" do
          expect(resource["Properties"]["Tags"]).to eq([{"Key"=>"Name", "Value"=>"ecs-task"}, {"Key"=>"Environment", "Value"=>{"Ref"=>"EnvironmentName"}}, {"Key"=>"EnvironmentType", "Value"=>{"Ref"=>"EnvironmentType"}}, {"Key"=>"CostCenter", "Value"=>"TeamA"}])
      end
      
    end
    
  end

end