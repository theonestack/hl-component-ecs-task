require 'yaml'

describe 'compiled component ecs-task' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/volumes-hash.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/volumes-hash/ecs-task.compiled.yaml") }
  
  context "Resource" do

    context "Task" do
      let(:resource) { template["Resources"]["Task"] }

      it "is of type AWS::ECS::TaskDefinition" do
        expect(resource["Type"]).to eq("AWS::ECS::TaskDefinition")
      end

      it "has Volumes with correct format" do
        volumes = resource["Properties"]["Volumes"]
        expect(volumes).to be_an(Array)
        expect(volumes.length).to eq(2)
      end

      it "has s3-data volume with host path" do
        volumes = resource["Properties"]["Volumes"]
        s3_volume = volumes.find { |v| v["Name"] == "s3-data" }
        expect(s3_volume).not_to be_nil
        expect(s3_volume["Host"]["SourcePath"]).to eq("/mnt/s3")
      end

      it "has efs-shared volume with host path" do
        volumes = resource["Properties"]["Volumes"]
        efs_volume = volumes.find { |v| v["Name"] == "efs-shared" }
        expect(efs_volume).not_to be_nil
        expect(efs_volume["Host"]["SourcePath"]).to eq("/mnt/efs")
      end

      it "has MountPoints on the container" do
        container = resource["Properties"]["ContainerDefinitions"][0]
        mount_points = container["MountPoints"]
        expect(mount_points).to be_an(Array)
        expect(mount_points.length).to eq(2)
      end

      it "has s3-data mount point with correct config" do
        container = resource["Properties"]["ContainerDefinitions"][0]
        mount_points = container["MountPoints"]
        s3_mount = mount_points.find { |m| m["SourceVolume"] == "s3-data" }
        expect(s3_mount).not_to be_nil
        expect(s3_mount["ContainerPath"]).to eq("/mnt/s3")
        expect(s3_mount["ReadOnly"]).to eq(false)
      end

      it "has efs-shared mount point as read-only" do
        container = resource["Properties"]["ContainerDefinitions"][0]
        mount_points = container["MountPoints"]
        efs_mount = mount_points.find { |m| m["SourceVolume"] == "efs-shared" }
        expect(efs_mount).not_to be_nil
        expect(efs_mount["ContainerPath"]).to eq("/mnt/efs")
        expect(efs_mount["ReadOnly"]).to eq(true)
      end

      it "has RequiresCompatibilities EC2" do
        expect(resource["Properties"]["RequiresCompatibilities"]).to eq(["EC2"])
      end

      it "has NetworkMode host" do
        expect(resource["Properties"]["NetworkMode"]).to eq("host")
      end
    end

  end

end
