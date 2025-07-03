#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_requirements() {
    print_status "Checking requirements..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
    
    print_status "Requirements check passed"
}

# Deploy local stack
deploy_local() {
    print_status "Deploying local monitoring stack..."
    
    if [ -z "$TELE_TOKEN" ]; then
        print_warning "TELE_TOKEN not set, using placeholder"
        export TELE_TOKEN="placeholder_token"
    fi
    
    if [ "$1" = "with-kbot" ]; then
        print_status "Starting stack with kbot..."
        docker-compose -f docker-compose.kbot.yaml up -d
    else
        print_status "Starting monitoring stack only..."
        docker-compose up -d
    fi
    
    print_status "Local stack deployed successfully!"
    print_status "Access points:"
    echo "  - Grafana: http://localhost:3000 (admin/admin)"
    echo "  - Prometheus: http://localhost:9090"
    echo "  - Loki: http://localhost:3100"
    if [ "$1" = "with-kbot" ]; then
        echo "  - KBot metrics: http://localhost:8080/metrics"
    fi
}

# Deploy Kubernetes stack
deploy_k8s() {
    print_status "Deploying Kubernetes monitoring stack..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
    
    if [ -z "$TELE_TOKEN" ]; then
        print_error "TELE_TOKEN environment variable is required for Kubernetes deployment"
        exit 1
    fi
    
    cd k8s
    
    print_status "Creating namespace..."
    kubectl apply -f namespace.yaml
    
    print_status "Creating kbot secret..."
    kubectl create secret generic kbot-secret \
        --from-literal=tele-token="$TELE_TOKEN" \
        -n monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    print_status "Deploying monitoring stack..."
    kubectl apply -k .
    
    print_status "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=300s
    kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s
    kubectl wait --for=condition=ready pod -l app=loki -n monitoring --timeout=300s
    
    print_status "Kubernetes stack deployed successfully!"
    print_status "To access services, run:"
    echo "  kubectl port-forward svc/grafana 3000:3000 -n monitoring"
    echo "  kubectl port-forward svc/prometheus 9090:9090 -n monitoring"
    echo "  kubectl port-forward svc/loki 3100:3100 -n monitoring"
}

# Deploy Flux GitOps
deploy_flux() {
    print_status "Deploying Flux GitOps stack..."
    
    if ! command -v flux &> /dev/null; then
        print_error "Flux CLI is not installed"
        print_status "Install Flux CLI: curl -s https://fluxcd.io/install.sh | sudo bash"
        exit 1
    fi
    
    if [ -z "$GITHUB_USER" ] || [ -z "$GITHUB_REPO" ]; then
        print_error "GITHUB_USER and GITHUB_REPO environment variables are required for Flux deployment"
        exit 1
    fi
    
    print_status "Bootstrapping Flux..."
    flux bootstrap github \
        --owner="$GITHUB_USER" \
        --repository="$GITHUB_REPO" \
        --branch=main \
        --path=./monitoring/k8s \
        --personal
    
    print_status "Applying Flux sync configuration..."
    kubectl apply -f ../flux/gotk-sync.yaml
    
    print_status "Flux GitOps stack deployed successfully!"
    print_status "Check status with:"
    echo "  flux get kustomizations"
    echo "  flux get sources git"
}

# Show usage
usage() {
    echo "Usage: $0 [OPTIONS] COMMAND"
    echo ""
    echo "Commands:"
    echo "  local [with-kbot]    Deploy local stack (optionally with kbot)"
    echo "  k8s                  Deploy Kubernetes stack"
    echo "  flux                 Deploy Flux GitOps stack"
    echo "  status               Show deployment status"
    echo "  cleanup              Clean up deployment"
    echo ""
    echo "Environment variables:"
    echo "  TELE_TOKEN          Telegram bot token (required for k8s/flux)"
    echo "  GITHUB_USER         GitHub username (required for flux)"
    echo "  GITHUB_REPO         GitHub repository name (required for flux)"
    echo ""
    echo "Examples:"
    echo "  $0 local                    # Deploy local monitoring stack"
    echo "  $0 local with-kbot          # Deploy local stack with kbot"
    echo "  TELE_TOKEN=xxx $0 k8s       # Deploy Kubernetes stack"
    echo "  GITHUB_USER=user GITHUB_REPO=repo TELE_TOKEN=xxx $0 flux"
}

# Show status
show_status() {
    print_status "Checking deployment status..."
    
    if docker ps | grep -q "monitoring"; then
        print_status "Local stack is running:"
        docker ps --filter "name=monitoring" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        print_warning "No local stack containers found"
    fi
    
    if command -v kubectl &> /dev/null; then
        if kubectl get namespace monitoring &> /dev/null; then
            print_status "Kubernetes stack status:"
            kubectl get pods -n monitoring
        else
            print_warning "No Kubernetes monitoring namespace found"
        fi
    fi
}

# Cleanup
cleanup() {
    print_status "Cleaning up deployment..."
    
    # Stop local containers
    if [ -f "docker-compose.yaml" ]; then
        docker-compose down
        docker-compose -f docker-compose.kbot.yaml down
    fi
    
    # Delete Kubernetes resources
    if command -v kubectl &> /dev/null; then
        kubectl delete namespace monitoring --ignore-not-found=true
    fi
    
    print_status "Cleanup completed"
}

# Main script logic
main() {
    case "${1:-}" in
        local)
            check_requirements
            deploy_local "$2"
            ;;
        k8s)
            check_requirements
            deploy_k8s
            ;;
        flux)
            check_requirements
            deploy_flux
            ;;
        status)
            show_status
            ;;
        cleanup)
            cleanup
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@" 