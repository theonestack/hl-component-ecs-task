CloudFormation do

    export = external_parameters.fetch(:task_export_name, nil)
    export = external_parameters.fetch(:export_name, external_parameters[:component_name]) if export.nil?
    
    task_tags = []
    task_tags << { Key: "Name", Value: external_parameters[:component_name] }
    task_tags << { Key: "Environment", Value: Ref("EnvironmentName") }
    task_tags << { Key: "EnvironmentType", Value: Ref("EnvironmentType") }

    tags = external_parameters.fetch(:tags, [])
    tags.each do |key,value|
      task_tags << { Key: key, Value: value }
    end

    log_retention = external_parameters.fetch(:log_retention, 7)
    log_group_name = external_parameters.fetch(:log_group_name, Ref('AWS::StackName'))
    Logs_LogGroup('LogGroup') {
      LogGroupName log_group_name
      RetentionInDays log_retention
    }

    definitions, task_volumes, secrets = Array.new(4){[]}
    task_constraints =[];
    secrets_policy = {}

    task_definition = external_parameters.fetch(:task_definition, {})
    task_definition.each do |task_name, task|

      env_vars, mount_points, ports = Array.new(3){[]}

      name = task.has_key?('name') ? task['name'] : task_name

      image_repo = task.has_key?('repo') ? "#{task['repo']}" : ''
      image_name = task.has_key?('image') ? task['image'] : task_name
      image_tag = task.has_key?('tag') ? "#{task['tag']}" : 'latest'
      image_tag = task.has_key?('tag_param') ? Ref("#{task['tag_param']}") : image_tag

      # create main definition
      task_def =  {
        Name: name,
        Image: FnJoin('', [FnSub("#{image_repo}/#{image_name}"), ":", image_tag]),
        LogConfiguration: {
          LogDriver: 'awslogs',
          Options: {
            'awslogs-group' => Ref("LogGroup"),
            "awslogs-region" => Ref("AWS::Region"),
            "awslogs-stream-prefix" => name
          }
        }
      }

      if task.has_key?('log_pattern')
        task_def[:LogConfiguration][:Options]["awslogs-multiline-pattern"] = task['log_pattern']
      end

      task_def.merge!({ MemoryReservation: task['memory'] }) if task.has_key?('memory')
      task_def.merge!({ Cpu: task['cpu'] }) if task.has_key?('cpu')

      task_def.merge!({ Ulimits: task['ulimits'] }) if task.has_key?('ulimits')

      task_def.merge!({ StartTimeout: task['start_timeout'] }) if task.has_key?('start_timeout')
      task_def.merge!({ StopTimeout: task['stop_timeout'] }) if task.has_key?('stop_timeout')


      if !(task['env_vars'].nil?)
        task['env_vars'].each do |name,value|
          split_value = value.to_s.split(/\${|}/)
          if split_value.include? 'environment'
            fn_join = split_value.map { |x| x == 'environment' ? [ Ref('EnvironmentName'), '.', FnFindInMap('AccountId',Ref('AWS::AccountId'),'DnsDomain') ] : x }
            env_value = FnJoin('', fn_join.flatten)
          elsif value == 'cf_version'
            env_value = cf_version
          else
            env_value = value
          end
          env_vars << { Name: name, Value: env_value}
        end
      end

      task_def.merge!({Environment: env_vars }) if env_vars.any?

      # add links
      if task.key?('links')
        task['links'].each do |links|
        task_def.merge!({ Links: [ links ] })
        end
      end

      # add entrypoint
      if task.key?('entrypoint')
        task['entrypoint'].each do |entrypoint|
        task_def.merge!({ EntryPoint: entrypoint })
        end
      end

      # By default Essential is true, switch to false if `not_essential: true`
      task_def.merge!({ Essential: false }) if task['not_essential']

      # add docker volumes
      if task.key?('mounts')
        task['mounts'].each do |mount|
          if mount.is_a? String 
            parts = mount.split(':',2)
            mount_points << { ContainerPath: FnSub(parts[0]), SourceVolume: FnSub(parts[1]), ReadOnly: (parts[2] == 'ro' ? true : false) }
          else
            mount_points << mount
          end
        end
        task_def.merge!({MountPoints: mount_points })
      end

      # add volumes from
      volumes_from = []
      if task.key?('volumes_from')
        if task['volumes_from'].kind_of?(Array)
          task['volumes_from'].each do |source_container|
            volumes_from << { SourceContainer: source_container }
          end
          task_def.merge!({ VolumesFrom: volumes_from })
        end
      end

      # add ebs volumes
      ebs_volumes = external_parameters.fetch(:ebs_volumes, [])
      ebs_volumes.each do |ebs_volume|
        EC2_Volume(ebs_volume['name']) do
          Size 100
          VolumeType "gp3"
          AvailabilityZone Ref(:EbsAZ)
        end
        
        task_constraints << {Type: "memberOf", Expression: "attribute:ecs.availability-zone in #{Ref(:EbsAZ)}"}
        mount_points << { ContainerPath: ebs_volume['container_path'], SourceVolume: Ref(ebs_volume['name']), ReadOnly: false}
        task_volumes << { Name: Ref(ebs_volume['name']), ConfiguredAtLaunch: true }
        task_def.merge!({MountPoints: mount_points })
      end

      # add port
      if task.key?('ports')
        port_mapppings = []
        task['ports'].each do |port|
          port_array = port.to_s.split(":").map(&:to_i)
          mapping = {}
          mapping.merge!(ContainerPort: port_array[0])
          mapping.merge!(HostPort: port_array[1]) if port_array.length == 2
          port_mapppings << mapping
        end
        task_def.merge!({PortMappings: port_mapppings})
      end

      # add DependsOn
      # The dependencies defined for container startup and shutdown. A container can contain multiple dependencies. When a dependency is defined for container startup, for container shutdown it is reversed.
      # For tasks using the EC2 launch type, the container instances require at least version 1.3.0 of the container agent to enable container dependencies
      depends_on = []
      if !(task['depends_on'].nil?)
        task['depends_on'].each do |name,value|
          depends_on << { ContainerName: name, Condition: value}
        end
      end

      linux_parameters = {}
    
      if task.key?('cap_add')
        linux_parameters[:Capabilities] = {Add: task['cap_add']}
      end
      
      if task.key?('cap_drop')
        if linux_parameters.key?(:Capabilities)
          linux_parameters[:Capabilities][:Drop] = task['cap_drop']
        else
          linux_parameters[:Capabilities] = {Drop: task['cap_drop']}
        end
      end
      
      if task.key?('init')
        linux_parameters[:InitProcessEnabled] = task['init']
      end
      
      if task.key?('memory_swap')
        linux_parameters[:MaxSwap] = task['memory_swap'].to_i
      end
      
      if task.key?('shm_size')
        linux_parameters[:SharedMemorySize] = task['shm_size'].to_i
      end
      
      if task.key?('memory_swappiness')
        linux_parameters[:Swappiness] = task['memory_swappiness'].to_i
      end

      task_def.merge!({LinuxParameters: linux_parameters}) if linux_parameters.any?
      task_def.merge!({EntryPoint: task['entrypoint'] }) if task.key?('entrypoint')
      task_def.merge!({Command: task['command'] }) if task.key?('command')
      task_def.merge!({HealthCheck: task['healthcheck'] }) if task.key?('healthcheck')
      task_def.merge!({WorkingDirectory: task['working_dir'] }) if task.key?('working_dir')
      task_def.merge!({Privileged: task['privileged'] }) if task.key?('privileged')
      task_def.merge!({User: task['user'] }) if task.key?('user')
      task_def.merge!({DependsOn: depends_on }) if depends_on.length > 0
      task_def.merge!({ ExtraHosts: task['extra_hosts'] }) if task.has_key?('extra_hosts')

      if task.key?('secrets')
      
        if task['secrets'].key?('ssm')
          secrets.push *task['secrets']['ssm'].map {|k,v| { Name: k, ValueFrom: v.is_a?(String) && v.start_with?('/') ? FnSub("arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter#{v}") : v }}
          resources = task['secrets']['ssm'].map {|k,v| v.is_a?(String) && v.start_with?('/') ? FnSub("arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter#{v}") : v }
          secrets_policy['ssm-secrets'] = {
            'action' => 'ssm:GetParameters',
            'resource' => resources
          }
          task['secrets'].reject! { |k| k == 'ssm' }
        end
        
        if task['secrets'].key?('secretsmanager')
          secrets.push *task['secrets']['secretsmanager'].map {|k,v| { Name: k, ValueFrom: v.is_a?(String) && v.start_with?('/') ? FnSub("arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:#{v}") : v }}
          resources = task['secrets']['secretsmanager'].map {|k,v| v.is_a?(String) && v.start_with?('/') ? FnSub("arn:aws:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:#{v}-*") : v }
          secrets_policy['secretsmanager'] = {
            'action' => 'secretsmanager:GetSecretValue',
            'resource' => resources
          }
          task['secrets'].reject! { |k| k == 'secretsmanager' }
        end

        unless task['secrets'].empty?
          secrets.push *task['secrets'].map {|k,v| { Name: k, ValueFrom: v.is_a?(String) && v.start_with?('/') ? FnSub("arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter#{v}") : v }}
          resources = task['secrets'].map {|k,v| v.is_a?(String) && v.start_with?('/') ? FnSub("arn:aws:ssm:${AWS::Region}:${AWS::AccountId}:parameter#{v}") : v }
          secrets_policy['ssm-secrets-inline'] = {
            'action' => 'ssm:GetParameters',
            'resource' => resources
          }
        end
        
        if secrets.any?
          task_def.merge!({Secrets: secrets})
        end
        
      end

      definitions << task_def

    end

    # add docker volumes
    volumes = external_parameters.fetch(:volumes, [])
    volumes.each do |volume|
      if volume.is_a? String 
        parts = volume.split(':')
        object = { Name: FnSub(parts[0])}
        object.merge!({ Host: { SourcePath: FnSub(parts[1]) }}) if parts[1]
      else
        object = volume
      end
      task_volumes << object
    end

    # add task placement constraints 
    task_placement_constraints = external_parameters.fetch(:task_placement_constraints, [])
    task_placement_constraints.each do |cntr|
      object = {Type: "memberOf"} 
      object.merge!({ Expression: FnSub(cntr)})
      task_constraints << object
    end

    iam_policies = external_parameters.fetch(:iam_policies, {})
    service_discovery = external_parameters.fetch(:service_discovery, {})
    enable_execute_command = external_parameters.fetch(:enable_execute_command, false)

    if enable_execute_command
      iam_policies['ssm-session-manager'] = {
        'action' => %w(
          ssmmessages:CreateControlChannel
          ssmmessages:CreateDataChannel
          ssmmessages:OpenControlChannel
          ssmmessages:OpenDataChannel
        )
      }
    end

    unless iam_policies.empty?
  
      unless service_discovery.empty?
        iam_policies['ecs-service-discovery'] = {
          'action' => %w(
            servicediscovery:RegisterInstance
            servicediscovery:DeregisterInstance
            servicediscovery:DiscoverInstances
            servicediscovery:Get*
            servicediscovery:List*
            route53:GetHostedZone
            route53:ListHostedZonesByName
            route53:ChangeResourceRecordSets
            route53:CreateHealthCheck
            route53:GetHealthCheck
            route53:DeleteHealthCheck
            route53:UpdateHealthCheck
          )
        }
      end
  
      IAM_Role('TaskRole') do
        AssumeRolePolicyDocument service_assume_role_policy(['ecs-tasks','ssm'])
        Path '/'
        Policies(iam_role_policies(iam_policies))
      end
  
      IAM_Role('ExecutionRole') do
        AssumeRolePolicyDocument service_assume_role_policy(['ecs-tasks','ssm'])
        Path '/'
        ManagedPolicyArns ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
  
        if secrets_policy.any?
          Policies iam_role_policies(secrets_policy)
        end
  
      end
    end

    task_type = external_parameters.fetch(:task_type, 'EC2')
    unless task_definition.empty?

      ECS_TaskDefinition('Task') do
        ContainerDefinitions definitions
        RequiresCompatibilities [task_type]

        if external_parameters[:cpu]
          Cpu external_parameters[:cpu]
        end

        if external_parameters[:memory]
          Memory external_parameters[:memory]
        end

        if external_parameters[:network_mode]
          NetworkMode external_parameters[:network_mode]
        end

        if task_volumes.any?
          Volumes task_volumes
        end

        unless iam_policies.empty?
          TaskRoleArn Ref('TaskRole')
          ExecutionRoleArn Ref('ExecutionRole')
        end

        EphemeralStorage external_parameters[:ephemeral_storage] unless external_parameters[:ephemeral_storage].nil?

        Tags task_tags

      end


        Output("EcsTaskArn") {
          Value(Ref('Task'))
          Export FnSub("${EnvironmentName}-#{export}-EcsTaskArn")
        }
    end

  end
