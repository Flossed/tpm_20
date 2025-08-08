// Key Management functionality for TPM 2.0 Application

document.addEventListener('DOMContentLoaded', function() {
    initializeKeyManagement();
    loadKeysList();
});

function initializeKeyManagement() {
    console.log('TPM Key Management initialized');
    
    // Initialize create key modal
    initializeCreateKeyModal();
    
    // Initialize delete key functionality
    initializeDeleteKeyHandlers();
    
    // Initialize key details handlers
    initializeKeyDetailsHandlers();
}

function initializeCreateKeyModal() {
    const createKeyBtn = document.getElementById('createKeyBtn');
    const createKeyForm = document.getElementById('createKeyForm');
    const createKeyModal = document.getElementById('createKeyModal');
    
    if (createKeyBtn) {
        createKeyBtn.addEventListener('click', function() {
            const modal = new bootstrap.Modal(createKeyModal);
            modal.show();
        });
    }
    
    if (createKeyForm) {
        createKeyForm.addEventListener('submit', function(e) {
            e.preventDefault();
            handleCreateKey();
        });
    }
}

async function handleCreateKey() {
    const form = document.getElementById('createKeyForm');
    const submitBtn = document.querySelector('#createKeyForm button[type="submit"]');
    const originalText = submitBtn.textContent;
    
    try {
        // Show loading state
        submitBtn.disabled = true;
        submitBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Creating...';
        
        const formData = new FormData(form);
        const keyData = {
            keyName: formData.get('keyName'),
            description: formData.get('description')
        };
        
        // Validate input
        if (!keyData.keyName || keyData.keyName.trim().length === 0) {
            throw new Error('Key name is required');
        }
        
        const response = await fetch('/api/keys', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(keyData)
        });
        
        const result = await response.json();
        
        if (response.ok) {
            showNotification('TPM key created successfully!', 'success');
            
            // Close modal and reset form
            const modal = bootstrap.Modal.getInstance(document.getElementById('createKeyModal'));
            modal.hide();
            form.reset();
            
            // Refresh keys list
            await loadKeysList();
        } else {
            throw new Error(result.error || 'Failed to create key');
        }
        
    } catch (error) {
        console.error('Error creating key:', error);
        showNotification(error.message, 'danger');
    } finally {
        // Restore button state
        submitBtn.disabled = false;
        submitBtn.textContent = originalText;
    }
}

async function loadKeysList() {
    try {
        const response = await fetch('/api/keys');
        if (response.ok) {
            const keys = await response.json();
            displayKeysList(keys);
        } else {
            console.error('Failed to load keys');
        }
    } catch (error) {
        console.error('Error loading keys:', error);
        showNotification('Failed to load keys', 'warning');
    }
}

function displayKeysList(keys) {
    const keysTableBody = document.querySelector('#keysTable tbody');
    if (!keysTableBody) return;
    
    if (!keys || keys.length === 0) {
        keysTableBody.innerHTML = `
            <tr>
                <td colspan="6" class="text-center text-muted py-4">
                    <i class="bi bi-key fs-1 mb-2"></i>
                    <div>No TPM keys found</div>
                    <small>Create your first key to get started</small>
                </td>
            </tr>
        `;
        return;
    }
    
    const keysHtml = keys.map(key => `
        <tr data-key-id="${key._id}">
            <td>
                <strong>${escapeHtml(key.name)}</strong>
                ${key.metadata && key.metadata.get('description') ? 
                    `<br><small class="text-muted">${escapeHtml(key.metadata.get('description'))}</small>` : ''}
            </td>
            <td>
                <span class="badge bg-primary">${key.keyType || 'ES256'}</span>
            </td>
            <td>
                <span class="badge ${getStatusBadgeClass(key.status)}">${key.status}</span>
            </td>
            <td>${formatDate(key.createdAt)}</td>
            <td>
                <span class="badge bg-secondary">${key.usageCount || 0}</span>
                ${key.lastUsed ? `<br><small class="text-muted">Last: ${formatDate(key.lastUsed)}</small>` : ''}
            </td>
            <td>
                <div class="btn-group" role="group">
                    <button type="button" class="btn btn-sm btn-outline-primary" onclick="viewKeyDetails('${key._id}')">
                        <i class="bi bi-eye"></i>
                    </button>
                    <button type="button" class="btn btn-sm btn-outline-danger" onclick="confirmDeleteKey('${key._id}', '${escapeHtml(key.name)}')">
                        <i class="bi bi-trash"></i>
                    </button>
                </div>
            </td>
        </tr>
    `).join('');
    
    keysTableBody.innerHTML = keysHtml;
}

function getStatusBadgeClass(status) {
    const classes = {
        'active': 'bg-success',
        'disabled': 'bg-warning',
        'deleted': 'bg-danger'
    };
    return classes[status] || 'bg-secondary';
}

function initializeDeleteKeyHandlers() {
    const deleteKeyModal = document.getElementById('deleteKeyModal');
    const confirmDeleteBtn = document.getElementById('confirmDeleteBtn');
    
    if (confirmDeleteBtn) {
        confirmDeleteBtn.addEventListener('click', function() {
            const keyId = this.dataset.keyId;
            if (keyId) {
                handleDeleteKey(keyId);
            }
        });
    }
}

function confirmDeleteKey(keyId, keyName) {
    const modal = new bootstrap.Modal(document.getElementById('deleteKeyModal'));
    const keyNameElement = document.getElementById('deleteKeyName');
    const confirmBtn = document.getElementById('confirmDeleteBtn');
    
    if (keyNameElement) {
        keyNameElement.textContent = keyName;
    }
    
    if (confirmBtn) {
        confirmBtn.dataset.keyId = keyId;
    }
    
    modal.show();
}

// Global function for onclick handler in HTML
window.confirmDelete = function(keyId, keyName) {
    confirmDeleteKey(keyId, keyName);
}

async function handleDeleteKey(keyId) {
    const confirmBtn = document.getElementById('confirmDeleteBtn');
    const originalText = confirmBtn.textContent;
    
    try {
        // Show loading state
        confirmBtn.disabled = true;
        confirmBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Deleting...';
        
        const response = await fetch(`/api/keys/${keyId}`, {
            method: 'DELETE'
        });
        
        const result = await response.json();
        
        if (response.ok) {
            showNotification('Key deleted successfully', 'success');
            
            // Close modal
            const modal = bootstrap.Modal.getInstance(document.getElementById('deleteKeyModal'));
            modal.hide();
            
            // Refresh keys list
            await loadKeysList();
        } else {
            throw new Error(result.error || 'Failed to delete key');
        }
        
    } catch (error) {
        console.error('Error deleting key:', error);
        showNotification(error.message, 'danger');
    } finally {
        // Restore button state
        confirmBtn.disabled = false;
        confirmBtn.textContent = originalText;
    }
}

function viewKeyDetails(keyId) {
    window.location.href = `/keys/${keyId}`;
}

function initializeKeyDetailsHandlers() {
    // Handle CSR generation if on key details page
    const generateCSRBtn = document.getElementById('generateCSRBtn');
    if (generateCSRBtn) {
        generateCSRBtn.addEventListener('click', handleGenerateCSR);
    }
    
    // Handle certificate upload if on key details page
    const uploadCertForm = document.getElementById('uploadCertForm');
    if (uploadCertForm) {
        uploadCertForm.addEventListener('submit', handleCertificateUpload);
    }
    
    // Handle public key copying
    const copyPublicKeyBtn = document.getElementById('copyPublicKeyBtn');
    if (copyPublicKeyBtn) {
        copyPublicKeyBtn.addEventListener('click', copyPublicKey);
    }
}

async function handleGenerateCSR() {
    const keyId = document.querySelector('[data-key-id]')?.dataset.keyId;
    if (!keyId) return;
    
    const generateBtn = document.getElementById('generateCSRBtn');
    const originalText = generateBtn.textContent;
    
    try {
        generateBtn.disabled = true;
        generateBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Generating...';
        
        const formData = new FormData(document.getElementById('csrForm'));
        const csrData = {
            commonName: formData.get('commonName'),
            organization: formData.get('organization'),
            country: formData.get('country')
        };
        
        const response = await fetch(`/api/keys/${keyId}/csr`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(csrData)
        });
        
        const result = await response.json();
        
        if (response.ok) {
            document.getElementById('csrOutput').textContent = result.csr;
            showNotification('CSR generated successfully!', 'success');
        } else {
            throw new Error(result.error || 'Failed to generate CSR');
        }
        
    } catch (error) {
        console.error('Error generating CSR:', error);
        showNotification(error.message, 'danger');
    } finally {
        generateBtn.disabled = false;
        generateBtn.textContent = originalText;
    }
}

async function handleCertificateUpload(e) {
    e.preventDefault();
    
    const keyId = document.querySelector('[data-key-id]')?.dataset.keyId;
    if (!keyId) return;
    
    const form = e.target;
    const submitBtn = form.querySelector('button[type="submit"]');
    const originalText = submitBtn.textContent;
    
    try {
        submitBtn.disabled = true;
        submitBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Uploading...';
        
        const formData = new FormData(form);
        const certificateData = {
            certificate: formData.get('certificate')
        };
        
        const response = await fetch(`/api/keys/${keyId}/certificate`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(certificateData)
        });
        
        const result = await response.json();
        
        if (response.ok) {
            showNotification('Certificate uploaded successfully!', 'success');
            form.reset();
            // Refresh the page to show updated certificate
            window.location.reload();
        } else {
            throw new Error(result.error || 'Failed to upload certificate');
        }
        
    } catch (error) {
        console.error('Error uploading certificate:', error);
        showNotification(error.message, 'danger');
    } finally {
        submitBtn.disabled = false;
        submitBtn.textContent = originalText;
    }
}

function copyPublicKey() {
    const publicKeyElement = document.getElementById('publicKeyDisplay');
    if (!publicKeyElement) return;
    
    const publicKey = publicKeyElement.textContent;
    
    navigator.clipboard.writeText(publicKey).then(() => {
        showNotification('Public key copied to clipboard!', 'success');
        
        // Temporarily change button text
        const btn = document.getElementById('copyPublicKeyBtn');
        const originalText = btn.textContent;
        btn.textContent = 'Copied!';
        setTimeout(() => {
            btn.textContent = originalText;
        }, 2000);
        
    }).catch(() => {
        showNotification('Failed to copy public key', 'warning');
    });
}

// Utility functions
function formatDate(dateString) {
    if (!dateString) return 'Never';
    const date = new Date(dateString);
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
}

function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `alert alert-${type} alert-dismissible fade show position-fixed`;
    notification.style.top = '20px';
    notification.style.right = '20px';
    notification.style.zIndex = '9999';
    notification.style.minWidth = '300px';
    
    notification.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    document.body.appendChild(notification);
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
        if (notification.parentNode) {
            notification.remove();
        }
    }, 5000);
}

// Export functions for external use
window.TPMKeys = {
    loadKeysList,
    viewKeyDetails,
    confirmDeleteKey,
    copyPublicKey,
    showNotification
};