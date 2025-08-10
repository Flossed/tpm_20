// TPM Management JavaScript
let currentDeleteKeyId = null;

document.addEventListener('DOMContentLoaded', function() {
    initializeTPMManagement();
});

function initializeTPMManagement() {
    console.log('TPM Management page initialized');
    
    // Initialize modals
    const createModal = document.getElementById('createKeyModal');
    const deleteModal = document.getElementById('deleteKeyModal');
    
    // Reset forms when modals are closed
    if (createModal) {
        createModal.addEventListener('hidden.bs.modal', resetCreateForm);
    }
    
    if (deleteModal) {
        deleteModal.addEventListener('hidden.bs.modal', resetDeleteForm);
    }
}

async function createTPMKey() {
    const form = document.getElementById('createKeyForm');
    const keyName = document.getElementById('keyName').value.trim();
    const createBtn = document.getElementById('createKeyBtn');
    
    if (!keyName) {
        showNotification('Please enter a key name', 'danger');
        return;
    }
    
    // Disable button and show loading
    createBtn.disabled = true;
    createBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Creating...';
    
    try {
        const response = await fetch('/api/keys', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                keyName: keyName,
                useTPM: true
            })
        });
        
        const result = await response.json();
        
        if (response.ok) {
            showNotification(`TPM key "${keyName}" created successfully!`, 'success');
            
            // Close modal and reload page
            const modal = bootstrap.Modal.getInstance(document.getElementById('createKeyModal'));
            modal.hide();
            
            // Reload page to show new key
            setTimeout(() => {
                window.location.reload();
            }, 1500);
            
        } else {
            throw new Error(result.error || 'Failed to create key');
        }
        
    } catch (error) {
        console.error('Error creating TPM key:', error);
        showNotification(error.message, 'danger');
    } finally {
        // Re-enable button
        createBtn.disabled = false;
        createBtn.innerHTML = '<i class="bi bi-shield-plus"></i> Create Key';
    }
}

function confirmDeleteKey(keyId, keyName) {
    currentDeleteKeyId = keyId;
    document.getElementById('deleteKeyName').textContent = keyName;
    
    const deleteModal = new bootstrap.Modal(document.getElementById('deleteKeyModal'));
    deleteModal.show();
}

async function deleteTPMKey() {
    if (!currentDeleteKeyId) return;
    
    const deleteBtn = document.getElementById('confirmDeleteBtn');
    
    // Disable button and show loading
    deleteBtn.disabled = true;
    deleteBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Deleting...';
    
    try {
        const response = await fetch(`/api/keys/${currentDeleteKeyId}`, {
            method: 'DELETE'
        });
        
        const result = await response.json();
        
        if (response.ok) {
            showNotification('Key deleted successfully', 'success');
            
            // Close modal and reload page
            const modal = bootstrap.Modal.getInstance(document.getElementById('deleteKeyModal'));
            modal.hide();
            
            // Reload page to remove deleted key
            setTimeout(() => {
                window.location.reload();
            }, 1500);
            
        } else {
            throw new Error(result.error || 'Failed to delete key');
        }
        
    } catch (error) {
        console.error('Error deleting key:', error);
        showNotification(error.message, 'danger');
    } finally {
        // Re-enable button
        deleteBtn.disabled = false;
        deleteBtn.innerHTML = '<i class="bi bi-trash"></i> Delete Key';
    }
}

async function generateCSR(keyId) {
    showNotification('CSR generation feature coming soon!', 'info');
    // TODO: Implement CSR generation modal and functionality
}

function resetCreateForm() {
    const form = document.getElementById('createKeyForm');
    if (form) {
        form.reset();
    }
    
    const createBtn = document.getElementById('createKeyBtn');
    if (createBtn) {
        createBtn.disabled = false;
        createBtn.innerHTML = '<i class="bi bi-shield-plus"></i> Create Key';
    }
}

function resetDeleteForm() {
    currentDeleteKeyId = null;
    
    const deleteBtn = document.getElementById('confirmDeleteBtn');
    if (deleteBtn) {
        deleteBtn.disabled = false;
        deleteBtn.innerHTML = '<i class="bi bi-trash"></i> Delete Key';
    }
}

function showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `alert alert-${type} alert-dismissible fade show position-fixed`;
    notification.style.cssText = 'top: 20px; right: 20px; z-index: 9999; min-width: 300px;';
    
    notification.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    // Add to page
    document.body.appendChild(notification);
    
    // Auto remove after 5 seconds
    setTimeout(() => {
        if (notification.parentNode) {
            notification.remove();
        }
    }, 5000);
}

// Utility function to format dates
function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
}

// Export functions for external use
window.TPMManagement = {
    createTPMKey,
    deleteTPMKey,
    confirmDeleteKey,
    generateCSR,
    showNotification
};