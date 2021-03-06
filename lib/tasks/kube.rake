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

    # Add the load balancer:
    apply 'https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.48.1/deploy/static/provider/cloud/deploy.yaml'

    # Add our own ingres specifications
    apply "#{Rails.root}/config/kube/ingress.yml"

    # Install cert-manager
    kubectl 'create namespace cert-manager'
    apply 'https://github.com/jetstack/cert-manager/releases/download/v1.4.1/cert-manager.yaml'

    # Add our certificate
    apply "#{Rails.root}/config/kube/certificate.yml"

    # Add the certificate issuer
    apply "#{Rails.root}/config/kube/cluster-issuer.yml"

    # Add the auto-scaler
    apply "#{Rails.root}/config/kube/autoscaler.yml"
  end

  desc 'Run migrations from Kube'
  task :migrate do
    apply "#{Rails.root}/config/kube/job-migrate.yml"
  end

  desc 'Tail log files from our app running in the cluster'
  task :logs do
    exec 'kubectl logs -f -l app=k8s-rails --all-containers'
  end

  desc 'Open a session to a pod on the cluster'
  task :shell do
    exec "kubectl exec -it #{find_first_pod_name} -- bash"
  end

  desc 'Runs a command in the server'
  task :run, [:command] => [:environment] do |_, args|
    kubectl "exec -it #{find_first_pod_name} echo $(#{args[:command]})"
  end

  desc 'Print the environment variables'
  task :config do
    system "kubectl exec -it #{find_first_pod_name} printenv | sort"
  end

  desc 'Run rails console on a pod'
  task :console do
    system "kubectl exec -it #{find_first_pod_name} bundle exec rails console"
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

  def find_first_pod_name
    `kubectl get pods|grep k8s-rails-deployment|awk '{print $1}'|head -n 1`.to_s.strip
  end
end
