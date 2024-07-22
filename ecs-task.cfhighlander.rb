CfhighlanderTemplate do

    Description "ecs-task - #{component_name} - #{component_version}"

    DependsOn 'lib-iam'

    Parameters do
      ComponentParam 'EnvironmentName', 'dev', isGlobal: true
      ComponentParam 'EnvironmentType', 'development', allowedValues: ['development','production'], isGlobal: true
      ComponentParam 'EbsAZ', ''

      task_definition.each do |task_def, task|
        if task.has_key?('tag_param')
          default_value = task.has_key?('tag_param_default') ? task['tag_param_default'] : 'latest'
          ComponentParam task['tag_param'], default_value
        end
      end if defined? task_definition

    end

  end
