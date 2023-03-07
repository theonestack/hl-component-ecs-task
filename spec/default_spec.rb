require 'yaml'

describe 'compiled component' do
  
  context 'cftest' do
    it 'compiles test' do
      expect(system("cfhighlander cftest #{@validate} --tests tests/default.test.yaml")).to be_truthy
    end      
  end
  
  let(:template) { YAML.load_file("#{File.dirname(__FILE__)}/../out/tests/default/ecs-task.compiled.yaml") }

  context 'Resources' do
    it 'has No Task ' do
      expect(template["Resources"]['Task']).to eq(nil)
    end

    it 'has a Log Group' do
      expect(template["Resources"]['LogGroup']).to eq({
        "Type"=>"AWS::Logs::LogGroup",
        "Properties"=>{"LogGroupName"=>{"Ref"=>"AWS::StackName"}, "RetentionInDays"=>7}
      })
    end
  end

end
