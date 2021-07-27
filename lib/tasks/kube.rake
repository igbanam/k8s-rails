# frozen_string_literal: true

require 'dotenv/tasks'

Dotenv.load('.env.production.cluster')

# Turn off Rake noise
Rake.application.options.trace = false

namespace :kube do
  desc 'Print useful information aout our Kubernetes setup'
  task :list do
    kubectl 'get all --all-namespaces'
  end

  desc 'Apply Kubernetes components'
  task :setup do
    kubectl(%Q{create secret docker-registry regcred \
        --docker-server=#{ENV['DOCKER_REGISTRY_SERVER']} \
        --docker-username=#{ENV['DOCKER_USERNAME']} \
        --docker-password=#{ENV['DOCKER_PASSWORD']} \
        --docker-email=#{ENV['DOCKER_EMAIL']} || true
    })

    # Apply the service component
    apply "#{Rails.root}/config/kube/service.yml"

    # Apply our Deployment component
    apply "#{Rails.root}/config/kube/deployment.yml"
  end

  def kubectl(command)
    puts `kubectl #{command}`
  end

  def apply(configuration)
    if File.file?(configuration)
      puts `envsubst < #{configuration} | kubectl apply -f -`
    else
      kubectl "apply -f #{configuration}"
    end
  end
end
