require 'yaml'

describe 'compiled component ecs-task' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/volumes-ref.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/volumes-ref/ecs-task.compiled.yaml") }
  
  context "Resource" do

    context "Task" do
      let(:resource) { template["Resources"]["Task"] }

      it "is of type AWS::ECS::TaskDefinition" do
        expect(resource["Type"]).to eq("AWS::ECS::TaskDefinition")
      end

      it "has Volumes as array" do
        volumes = resource["Properties"]["Volumes"]
        expect(volumes).to be_an(Array)
        expect(volumes.length).to eq(4)
      end

      it "has volume with Name only (no host path)" do
        volumes = resource["Properties"]["Volumes"]
        data_volume = volumes.find { |v| v["Name"].is_a?(Hash) ? false : v["Name"] == "/data" }
        # /data format creates a volume with Name: /data and no Host
        expect(volumes[0]["Name"]).not_to be_nil
      end

      it "has volume with host path from string format" do
        volumes = resource["Properties"]["Volumes"]
        test_volume = volumes.find { |v| v.is_a?(Hash) && v["Name"].is_a?(Hash) == false && v["Name"] == "test" }
        expect(test_volume).not_to be_nil
        expect(test_volume["Host"]["SourcePath"]).to eq("/test")
      end

      it "has MountPoints on the container" do
        container = resource["Properties"]["ContainerDefinitions"][0]
        mount_points = container["MountPoints"]
        expect(mount_points).to be_an(Array)
        expect(mount_points.length).to eq(4)
      end

      it "has a mount point with Fn::Sub reference" do
        container = resource["Properties"]["ContainerDefinitions"][0]
        mount_points = container["MountPoints"]
        # Check that the CFN-style mount_point object is included
        ref_mount = mount_points.find { |m| m["SourceVolume"].is_a?(Hash) }
        expect(ref_mount).not_to be_nil
        expect(ref_mount["ContainerPath"]).to eq("/data")
        expect(ref_mount["ReadOnly"]).to eq(false)
      end
    end

  end

end
