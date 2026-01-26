#!/bin/bash

echo "=== Minikube Resource Usage Report ==="
echo "Generated: $(date)"
echo

# Basic minikube info
echo "--- Minikube Status ---"
minikube status
echo

echo "--- Minikube Configuration ---"
echo "Memory: $(minikube config get memory 2>/dev/null || echo 'default')"
echo "CPUs: $(minikube config get cpus 2>/dev/null || echo 'default')"
echo "Disk Size: $(minikube config get disk-size 2>/dev/null || echo 'default')"
echo "Driver: $(minikube config get driver 2>/dev/null || echo 'default')"
echo

# VM-level info (if using KVM)
if minikube config get driver 2>/dev/null | grep -q kvm; then
    echo "--- KVM VM Information ---"
    if virsh -c qemu:///system dominfo minikube &>/dev/null; then
        virsh -c qemu:///system dominfo minikube
        echo
        
        echo "--- VM Memory Stats ---"
        virsh -c qemu:///system dommemstat minikube 2>/dev/null || echo "Memory stats not available"
        echo
        
        echo "--- VM Disk Usage ---"
        virsh -c qemu:///system domblklist minikube
        echo
        
        # Check actual disk file sizes
        echo "--- Disk File Sizes ---"
        minikube_path=$(virsh -c qemu:///system domblklist minikube | grep -o '/.*\.rawdisk\|/.*\.qcow2' | head -1)
        if [ -n "$minikube_path" ]; then
            ls -lh "$minikube_path"
            echo "Disk usage: $(du -sh "$minikube_path" | cut -f1)"
        fi
    else
        echo "KVM domain 'minikube' not found or not accessible"
    fi
    echo
fi

# Host system impact
echo "--- Host System Impact ---"
echo "Minikube processes:"
ps aux | grep -E "(minikube|qemu.*minikube)" | grep -v grep
echo

echo "--- Host Memory Usage ---"
free -h
echo

# Memory usage analysis
total_mem=$(free -b | awk 'NR==2{print $2}')
available_mem=$(free -b | awk 'NR==2{print $7}')
used_percentage=$(echo "scale=1; ($total_mem - $available_mem) * 100 / $total_mem" | bc -l 2>/dev/null || echo "N/A")

echo "Memory Usage Analysis:"
echo "- Used: ${used_percentage}% of total memory"
if [ "${available_mem}" -lt 2147483648 ]; then  # Less than 2GB available
    echo "⚠️  WARNING: Low available memory (< 2GB) - may cause minikube issues"
fi
echo

echo "--- Top Memory Consumers ---"
ps aux --sort=-%mem | head -6
echo

echo "--- Minikube Directory Usage ---"
if [ -d ~/.minikube ]; then
    du -sh ~/.minikube/
    echo "Breakdown:"
    du -sh ~/.minikube/*/ 2>/dev/null | sort -hr
fi
echo

# Kubernetes resource usage
echo "--- Kubernetes Node Resources ---"
if kubectl cluster-info &>/dev/null; then
    kubectl get nodes -o wide
    echo
    
    echo "--- Node Resource Usage ---"
    kubectl top node 2>/dev/null || echo "Metrics server not available"
    echo
    
    echo "--- Pod Resource Usage (Top 10) ---"
    kubectl top pods --all-namespaces --sort-by=memory 2>/dev/null | head -11 || echo "Metrics server not available"
    echo
    
    echo "--- Cluster Resource Requests/Limits ---"
    kubectl describe nodes minikube | grep -A 10 "Allocated resources:"
else
    echo "Kubernetes cluster not accessible"
fi
echo

echo "--- Docker Usage (if applicable) ---"
if command -v docker &>/dev/null && docker info &>/dev/null; then
    echo "Docker system usage:"
    docker system df
    echo
    echo "Running containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Size}}"
fi

echo "=== End of Report ==="
