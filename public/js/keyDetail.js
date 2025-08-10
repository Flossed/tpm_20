// Key Detail Page JavaScript
let currentKeyId = null;
let currentKeyName = null;

document.addEventListener('DOMContentLoaded', function() {
    initializeKeyDetail();
});

function initializeKeyDetail() {
    console.log('Key detail page initialized');
    
    // Initialize forms
    const csrForm = document.getElementById('csrForm');
    if (csrForm) {
        csrForm.addEventListener('submit', handleGenerateCSR);
    }
    
    const uploadCertForm = document.getElementById('uploadCertForm');
    if (uploadCertForm) {
        uploadCertForm.addEventListener('submit', handleUploadCertificate);
    }
    
    const confirmDeleteBtn = document.getElementById('confirmDeleteBtn');
    if (confirmDeleteBtn) {
        confirmDeleteBtn.addEventListener('click', handleDeleteKey);
    }
}

function confirmDelete(keyId, keyName) {
    currentKeyId = keyId;
    currentKeyName = keyName;
    
    // Set the key name in the modal
    document.getElementById('deleteKeyName').textContent = keyName;
    
    // Show the modal
    const deleteModal = new bootstrap.Modal(document.getElementById('deleteKeyModal'));
    deleteModal.show();
}

async function handleDeleteKey() {
    if (!currentKeyId) return;
    
    const confirmBtn = document.getElementById('confirmDeleteBtn');
    const spinner = confirmBtn.querySelector('.spinner-border');
    
    // Show loading state
    spinner.classList.remove('d-none');
    confirmBtn.disabled = true;
    
    try {
        const response = await fetch(`/api/keys/${currentKeyId}`, {
            method: 'DELETE'
        });
        
        const result = await response.json();
        
        if (response.ok) {
            showNotification('Key deleted successfully', 'success');
            
            // Redirect to keys page after a short delay
            setTimeout(() => {
                window.location.href = '/keys';
            }, 1500);
        } else {
            throw new Error(result.error || 'Failed to delete key');
        }
    } catch (error) {
        console.error('Error deleting key:', error);
        showNotification(error.message, 'danger');
        
        // Re-enable button
        spinner.classList.add('d-none');
        confirmBtn.disabled = false;
    }
}

async function handleGenerateCSR(event) {
    event.preventDefault();
    
    const form = event.target;
    const submitBtn = form.querySelector('button[type="submit"]');
    const spinner = submitBtn.querySelector('.spinner-border');
    
    // Get form data
    const commonName = document.getElementById('commonName').value;
    const organization = document.getElementById('organization').value;
    const country = document.getElementById('country').value;
    
    // Get key ID from URL
    const keyId = window.location.pathname.split('/').pop();
    
    // Show loading state
    spinner.classList.remove('d-none');
    submitBtn.disabled = true;
    
    try {
        const response = await fetch(`/api/keys/${keyId}/csr`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                commonName,
                organization,
                country
            })
        });
        
        const result = await response.json();
        
        if (response.ok) {
            showNotification('CSR generated successfully', 'success');
            
            // Close modal and reload page
            const modal = bootstrap.Modal.getInstance(document.getElementById('csrModal'));
            modal.hide();
            
            // Reload to show the CSR
            setTimeout(() => {
                window.location.reload();
            }, 1500);
        } else {
            throw new Error(result.error || 'Failed to generate CSR');
        }
    } catch (error) {
        console.error('Error generating CSR:', error);
        showNotification(error.message, 'danger');
    } finally {
        // Re-enable button
        spinner.classList.add('d-none');
        submitBtn.disabled = false;
    }
}

async function handleUploadCertificate(event) {
    event.preventDefault();
    
    const form = event.target;
    const submitBtn = form.querySelector('button[type="submit"]');
    const spinner = submitBtn.querySelector('.spinner-border');
    
    // Get form data
    const certificate = document.getElementById('certificate').value;
    
    // Get key ID from URL
    const keyId = window.location.pathname.split('/').pop();
    
    // Show loading state
    spinner.classList.remove('d-none');
    submitBtn.disabled = true;
    
    try {
        const response = await fetch(`/api/keys/${keyId}/certificate`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                certificate
            })
        });
        
        const result = await response.json();
        
        if (response.ok) {
            showNotification('Certificate uploaded successfully', 'success');
            
            // Close modal and reload page
            const modal = bootstrap.Modal.getInstance(document.getElementById('uploadCertModal'));
            modal.hide();
            
            // Reload to show the certificate
            setTimeout(() => {
                window.location.reload();
            }, 1500);
        } else {
            throw new Error(result.error || 'Failed to upload certificate');
        }
    } catch (error) {
        console.error('Error uploading certificate:', error);
        showNotification(error.message, 'danger');
    } finally {
        // Re-enable button
        spinner.classList.add('d-none');
        submitBtn.disabled = false;
    }
}

function copyToClipboard(elementId) {
    const element = document.getElementById(elementId);
    if (!element) return;
    
    // Select the text
    element.select();
    element.setSelectionRange(0, 99999); // For mobile devices
    
    // Copy to clipboard
    try {
        document.execCommand('copy');
        showNotification('Copied to clipboard!', 'success');
    } catch (err) {
        // Fallback for modern browsers
        navigator.clipboard.writeText(element.value).then(() => {
            showNotification('Copied to clipboard!', 'success');
        }).catch(err => {
            console.error('Failed to copy:', err);
            showNotification('Failed to copy to clipboard', 'danger');
        });
    }
    
    // Deselect the text
    element.blur();
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

// Export functions for external use
window.KeyDetail = {
    confirmDelete,
    copyToClipboard,
    showNotification
};