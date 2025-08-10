// Document Signing functionality for TPM 2.0 Application

document.addEventListener('DOMContentLoaded', function() {
    initializeSigningForm();
});

function initializeSigningForm() {
    console.log('Document signing form initialized');
    
    const signForm = document.getElementById('signDocumentForm');
    const keySelect = document.getElementById('keyId');
    const signBtn = document.getElementById('signBtn');
    
    if (signForm) {
        signForm.addEventListener('submit', handleDocumentSign);
    }
    
    if (keySelect) {
        keySelect.addEventListener('change', function() {
            const selectedKey = this.value;
            const keyDetails = document.getElementById('keyDetails');
            const selectedKeyName = document.getElementById('selectedKeyName');
            const selectedKeyType = document.getElementById('selectedKeyType');
            const selectedKeyUsage = document.getElementById('selectedKeyUsage');
            
            if (selectedKey) {
                // Show key details
                const option = this.options[this.selectedIndex];
                const keyName = option.dataset.keyName || option.text;
                const inTPM = option.dataset.inTpm === 'true';
                const usageCount = option.dataset.usageCount || '0';
                
                if (keyDetails) {
                    keyDetails.classList.remove('d-none');
                }
                
                if (selectedKeyName) selectedKeyName.textContent = keyName;
                if (selectedKeyType) selectedKeyType.textContent = inTPM ? 'ES256 (Hardware TPM)' : 'ES256 (Software)';
                if (selectedKeyUsage) selectedKeyUsage.textContent = usageCount;
                
                if (signBtn) {
                    signBtn.disabled = false;
                }
            } else {
                if (keyDetails) {
                    keyDetails.classList.add('d-none');
                }
                if (signBtn) {
                    signBtn.disabled = true;
                }
            }
        });
        
        // Only trigger change event if a key is already selected
        if (keySelect.value) {
            keySelect.dispatchEvent(new Event('change'));
        }
    }
}

async function handleDocumentSign(e) {
    e.preventDefault();
    
    const form = e.target;
    const submitBtn = form.querySelector('button[type="submit"]');
    const originalText = submitBtn.innerHTML;
    const keySelect = document.getElementById('keyId');
    const signedByInput = document.getElementById('signedBy');
    
    if (!keySelect.value) {
        showNotification('Please select a key to sign with', 'warning');
        return;
    }
    
    // Get document ID from hidden input or URL
    const documentIdInput = form.querySelector('input[name="documentId"]');
    const documentId = documentIdInput ? documentIdInput.value : window.location.pathname.split('/')[2];
    
    if (!documentId || documentId === 'undefined') {
        showNotification('Document ID not found. Please refresh the page and try again.', 'danger');
        return;
    }
    
    try {
        submitBtn.disabled = true;
        submitBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Signing...';
        
        const response = await fetch(`/api/documents/${documentId}/sign`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                keyId: keySelect.value,
                signedBy: signedByInput ? signedByInput.value : 'user'
            })
        });
        
        const result = await response.json();
        
        if (response.ok) {
            showNotification('Document signed successfully!', 'success');
            
            // Show signature details
            const signatureResult = document.getElementById('signatureResult');
            if (signatureResult) {
                const option = keySelect.options[keySelect.selectedIndex];
                const inTPM = option.dataset.inTpm === 'true';
                
                signatureResult.innerHTML = `
                    <div class="alert alert-success">
                        <h5 class="alert-heading">✅ Signature Created Successfully!</h5>
                        <hr>
                        <p><strong>Signature ID:</strong> <code>${result.signature.id}</code></p>
                        <p><strong>Signed At:</strong> ${new Date(result.signature.signedAt).toLocaleString()}</p>
                        <p><strong>Key Used:</strong> ${option.text} ${inTPM ? '(Hardware TPM)' : '(Software)'}</p>
                        <p class="mb-0">
                            <strong>Signature:</strong><br>
                            <code class="small" style="word-break: break-all;">${result.signature.signature.substring(0, 64)}...</code>
                        </p>
                    </div>
                `;
                signatureResult.style.display = 'block';
            }
            
            // Disable form after successful signing
            keySelect.disabled = true;
            submitBtn.disabled = true;
            submitBtn.innerHTML = '✅ Signed';
            
            // Redirect after delay
            setTimeout(() => {
                window.location.href = `/documents/${documentId}`;
            }, 3000);
            
        } else {
            throw new Error(result.error || 'Failed to sign document');
        }
        
    } catch (error) {
        console.error('Error signing document:', error);
        showNotification(error.message, 'danger');
        submitBtn.disabled = false;
        submitBtn.innerHTML = originalText;
    }
}

function showNotification(message, type = 'info') {
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
    
    setTimeout(() => {
        if (notification.parentNode) {
            notification.remove();
        }
    }, 5000);
}

// Export functions for external use
window.TPMSignDocument = {
    handleDocumentSign,
    showNotification
};