// Document Detail functionality for TPM 2.0 Application

document.addEventListener('DOMContentLoaded', function() {
    initializeDocumentDetail();
});

function initializeDocumentDetail() {
    console.log('Document detail page initialized');
    
    // Initialize markdown view toggle if present
    const viewModeRadios = document.querySelectorAll('input[name="viewMode"]');
    if (viewModeRadios.length > 0) {
        viewModeRadios.forEach(radio => {
            radio.addEventListener('change', toggleMarkdownView);
        });
    }
    
    // Initialize delete modals
    const confirmDeleteBtn = document.getElementById('confirmDeleteBtn');
    if (confirmDeleteBtn) {
        confirmDeleteBtn.addEventListener('click', handleDocumentDelete);
    }
    
    const confirmDeleteSignatureBtn = document.getElementById('confirmDeleteSignatureBtn');
    if (confirmDeleteSignatureBtn) {
        confirmDeleteSignatureBtn.addEventListener('click', handleSignatureDelete);
    }
    
    // Load signed documents
    loadSignedDocuments();
}

function toggleMarkdownView() {
    const rawContent = document.getElementById('rawContent');
    const renderedContent = document.getElementById('renderedContent');
    const viewRendered = document.getElementById('viewRendered');
    
    if (viewRendered && viewRendered.checked) {
        // Show rendered markdown
        if (rawContent) rawContent.classList.add('d-none');
        if (renderedContent) {
            renderedContent.classList.remove('d-none');
            // You could add markdown rendering here if needed
            renderedContent.innerHTML = '<p class="text-muted">Markdown rendering not implemented yet</p>';
        }
    } else {
        // Show raw content
        if (rawContent) rawContent.classList.remove('d-none');
        if (renderedContent) renderedContent.classList.add('d-none');
    }
}

async function verifySignature(signatureId) {
    try {
        const button = document.querySelector(`button[onclick="verifySignature('${signatureId}')"]`);
        const originalText = button.innerHTML;
        
        // Update button to show loading
        button.disabled = true;
        button.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span>Verifying...';
        
        const response = await fetch(`/api/signatures/${signatureId}/verify`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        });
        
        const result = await response.json();
        
        if (response.ok) {
            // Show verification result
            const statusCell = button.closest('tr').querySelector('td:nth-child(4)');
            const lastVerifiedCell = button.closest('tr').querySelector('td:nth-child(5)');
            
            if (result.valid) {
                statusCell.innerHTML = '<span class="badge bg-success"><i class="bi bi-check-circle"></i> Valid</span>';
                showNotification('Signature is valid and verified successfully!', 'success');
            } else {
                statusCell.innerHTML = '<span class="badge bg-danger"><i class="bi bi-x-circle"></i> Invalid</span>';
                showNotification('Signature verification failed - document may have been modified!', 'danger');
            }
            
            // Update last verified time
            lastVerifiedCell.innerHTML = `<small>${new Date().toLocaleString()}</small>`;
            
        } else {
            throw new Error(result.error || 'Failed to verify signature');
        }
        
    } catch (error) {
        console.error('Error verifying signature:', error);
        showNotification(error.message, 'danger');
    } finally {
        // Reset button
        const button = document.querySelector(`button[onclick="verifySignature('${signatureId}')"]`);
        if (button) {
            button.disabled = false;
            button.innerHTML = '<i class="bi bi-shield-check"></i> Verify';
        }
    }
}

async function showSignatureDetails(signatureId) {
    try {
        const response = await fetch(`/api/signatures/${signatureId}`);
        
        if (!response.ok) {
            throw new Error('Failed to load signature details');
        }
        
        const signature = await response.json();
        
        // Populate modal with signature details
        const modalContent = document.getElementById('signatureDetailsContent');
        modalContent.innerHTML = `
            <div class="row">
                <div class="col-md-6">
                    <h6>Signature Information</h6>
                    <dl class="row">
                        <dt class="col-sm-5">Signature ID:</dt>
                        <dd class="col-sm-7"><code>${signature._id}</code></dd>
                        
                        <dt class="col-sm-5">Algorithm:</dt>
                        <dd class="col-sm-7">ES256 (ECDSA P-256)</dd>
                        
                        <dt class="col-sm-5">Key Used:</dt>
                        <dd class="col-sm-7">${signature.keyId.name}</dd>
                        
                        <dt class="col-sm-5">Signed By:</dt>
                        <dd class="col-sm-7">${signature.signedBy}</dd>
                        
                        <dt class="col-sm-5">Signed At:</dt>
                        <dd class="col-sm-7">${new Date(signature.signedAt).toLocaleString()}</dd>
                    </dl>
                </div>
                <div class="col-md-6">
                    <h6>Verification Status</h6>
                    <dl class="row">
                        <dt class="col-sm-5">Status:</dt>
                        <dd class="col-sm-7">
                            ${signature.verificationStatus === 'valid' ? 
                                '<span class="badge bg-success">Valid</span>' : 
                                signature.verificationStatus === 'invalid' ? 
                                '<span class="badge bg-danger">Invalid</span>' : 
                                '<span class="badge bg-secondary">Unverified</span>'
                            }
                        </dd>
                        
                        <dt class="col-sm-5">Last Verified:</dt>
                        <dd class="col-sm-7">${signature.lastVerified ? new Date(signature.lastVerified).toLocaleString() : 'Never'}</dd>
                        
                        <dt class="col-sm-5">Verification Count:</dt>
                        <dd class="col-sm-7">${signature.verificationCount || 0}</dd>
                    </dl>
                </div>
            </div>
            
            <hr>
            
            <h6>Document Hash (SHA-256)</h6>
            <div class="input-group mb-3">
                <input type="text" class="form-control font-monospace small" value="${signature.documentHash}" readonly>
                <button class="btn btn-outline-primary" type="button" onclick="copyToClipboard('temp-hash', '${signature.documentHash}')">
                    <i class="bi bi-clipboard"></i>
                </button>
            </div>
            
            <h6>Digital Signature</h6>
            <div class="input-group">
                <textarea class="form-control font-monospace small" rows="4" readonly>${signature.signature}</textarea>
                <button class="btn btn-outline-primary" type="button" onclick="copyToClipboard('temp-sig', '${signature.signature}')">
                    <i class="bi bi-clipboard"></i>
                </button>
            </div>
        `;
        
        // Show modal
        const modal = new bootstrap.Modal(document.getElementById('signatureDetailsModal'));
        modal.show();
        
    } catch (error) {
        console.error('Error loading signature details:', error);
        showNotification('Failed to load signature details', 'danger');
    }
}

function downloadDocument() {
    // Create a download link for the document content
    const content = document.getElementById('documentContent').value;
    const filename = document.title.replace('Document: ', '') || 'document.txt';
    
    const blob = new Blob([content], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.style.display = 'none';
    
    document.body.appendChild(a);
    a.click();
    
    // Clean up
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    
    showNotification(`Downloaded: ${filename}`, 'success');
}

function confirmDeleteSignature(signatureId, keyName) {
    const modal = new bootstrap.Modal(document.getElementById('deleteSignatureModal'));
    const keyNameElement = document.getElementById('deleteSignatureKeyName');
    const confirmBtn = document.getElementById('confirmDeleteSignatureBtn');
    
    if (keyNameElement) {
        keyNameElement.textContent = keyName;
    }
    
    if (confirmBtn) {
        confirmBtn.dataset.signatureId = signatureId;
    }
    
    modal.show();
}

async function handleSignatureDelete() {
    const confirmBtn = document.getElementById('confirmDeleteSignatureBtn');
    const signatureId = confirmBtn.dataset.signatureId;
    const originalText = confirmBtn.innerHTML;
    
    if (!signatureId) {
        showNotification('Signature ID not found', 'danger');
        return;
    }
    
    try {
        confirmBtn.disabled = true;
        confirmBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Deleting...';
        
        const response = await fetch(`/api/signatures/${signatureId}`, {
            method: 'DELETE'
        });
        
        const result = await response.json();
        
        if (response.ok) {
            showNotification('Signature deleted successfully', 'success');
            
            // Close modal
            const modal = bootstrap.Modal.getInstance(document.getElementById('deleteSignatureModal'));
            modal.hide();
            
            // Remove the signature row from the table
            const signatureRow = document.querySelector(`button[onclick="verifySignature('${signatureId}')"]`).closest('tr');
            if (signatureRow) {
                signatureRow.remove();
            }
            
            // Update signature statistics
            updateSignatureStats();
            
            // Refresh page after short delay to update all counts
            setTimeout(() => {
                window.location.reload();
            }, 1000);
            
        } else {
            throw new Error(result.error || 'Failed to delete signature');
        }
        
    } catch (error) {
        console.error('Error deleting signature:', error);
        showNotification(error.message, 'danger');
    } finally {
        confirmBtn.disabled = false;
        confirmBtn.innerHTML = originalText;
    }
}

function updateSignatureStats() {
    // Update the signature count display
    const signatureTable = document.querySelector('#signatureTable tbody');
    if (signatureTable) {
        const remainingRows = signatureTable.querySelectorAll('tr').length;
        const totalCountElement = document.querySelector('.text-success');
        if (totalCountElement) {
            totalCountElement.textContent = remainingRows;
        }
    }
}

function confirmDelete(documentId, fileName) {
    const modal = new bootstrap.Modal(document.getElementById('deleteDocumentModal'));
    const fileNameElement = document.getElementById('deleteDocumentName');
    const confirmBtn = document.getElementById('confirmDeleteBtn');
    
    if (fileNameElement) {
        fileNameElement.textContent = fileName;
    }
    
    if (confirmBtn) {
        confirmBtn.dataset.documentId = documentId;
    }
    
    modal.show();
}

async function handleDocumentDelete() {
    const confirmBtn = document.getElementById('confirmDeleteBtn');
    const documentId = confirmBtn.dataset.documentId;
    const originalText = confirmBtn.innerHTML;
    
    if (!documentId) {
        showNotification('Document ID not found', 'danger');
        return;
    }
    
    try {
        confirmBtn.disabled = true;
        confirmBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Deleting...';
        
        const response = await fetch(`/api/documents/${documentId}`, {
            method: 'DELETE'
        });
        
        const result = await response.json();
        
        if (response.ok) {
            showNotification('Document deleted successfully', 'success');
            
            // Close modal
            const modal = bootstrap.Modal.getInstance(document.getElementById('deleteDocumentModal'));
            modal.hide();
            
            // Redirect to documents list after short delay
            setTimeout(() => {
                window.location.href = '/documents';
            }, 1000);
            
        } else {
            throw new Error(result.error || 'Failed to delete document');
        }
        
    } catch (error) {
        console.error('Error deleting document:', error);
        showNotification(error.message, 'danger');
    } finally {
        confirmBtn.disabled = false;
        confirmBtn.innerHTML = originalText;
    }
}

function copyToClipboard(elementId, textToCopy = null) {
    try {
        let text;
        
        if (textToCopy) {
            text = textToCopy;
        } else {
            const element = document.getElementById(elementId);
            if (!element) {
                throw new Error('Element not found');
            }
            text = element.value || element.textContent;
        }
        
        navigator.clipboard.writeText(text).then(() => {
            showNotification('Copied to clipboard!', 'success');
        }).catch(() => {
            // Fallback for older browsers
            const textArea = document.createElement('textarea');
            textArea.value = text;
            textArea.style.position = 'fixed';
            textArea.style.left = '-999999px';
            textArea.style.top = '-999999px';
            document.body.appendChild(textArea);
            textArea.focus();
            textArea.select();
            
            try {
                document.execCommand('copy');
                showNotification('Copied to clipboard!', 'success');
            } catch (err) {
                showNotification('Failed to copy to clipboard', 'danger');
            }
            
            document.body.removeChild(textArea);
        });
        
    } catch (error) {
        console.error('Error copying to clipboard:', error);
        showNotification('Failed to copy to clipboard', 'danger');
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

// Signed Documents Management
async function loadSignedDocuments() {
    try {
        const documentId = window.location.pathname.split('/')[2];
        const response = await fetch(`/api/documents/${documentId}/signed`);
        
        if (!response.ok) {
            throw new Error('Failed to load signed documents');
        }
        
        const signedDocs = await response.json();
        displaySignedDocuments(signedDocs);
        
    } catch (error) {
        console.error('Error loading signed documents:', error);
        const container = document.getElementById('signedDocumentsContainer');
        container.innerHTML = `
            <div class="text-center py-4 text-danger">
                <i class="bi bi-exclamation-triangle display-6 mb-3"></i>
                <h6>Failed to Load Signed Documents</h6>
                <p class="text-muted mb-3">${error.message}</p>
                <button class="btn btn-outline-primary" onclick="loadSignedDocuments()">
                    <i class="bi bi-arrow-clockwise"></i> Retry
                </button>
            </div>
        `;
    }
}

function displaySignedDocuments(signedDocs) {
    const container = document.getElementById('signedDocumentsContainer');
    
    if (!signedDocs || signedDocs.length === 0) {
        container.innerHTML = `
            <div class="text-center py-4">
                <i class="bi bi-file-earmark-check display-4 text-muted mb-3"></i>
                <h6 class="text-muted">No Signed Documents</h6>
                <p class="text-muted mb-4">Signed documents will appear here after you sign this document.</p>
                <a href="${window.location.pathname}/sign" class="btn btn-primary">
                    <i class="bi bi-pen"></i> Sign This Document
                </a>
            </div>
        `;
        return;
    }
    
    // Group signed documents by format
    const embedded = signedDocs.filter(doc => doc.format === 'embedded');
    const detached = signedDocs.filter(doc => doc.format === 'detached');
    
    let html = '<div class="row">';
    
    // Embedded signatures section
    if (embedded.length > 0) {
        html += `
            <div class="col-md-6">
                <h6><i class="bi bi-file-earmark-text text-primary"></i> Embedded Signatures (${embedded.length})</h6>
                <div class="list-group mb-3">
        `;
        
        embedded.forEach(doc => {
            const signedAt = new Date(doc.signatureId.signedAt).toLocaleDateString();
            html += `
                <div class="list-group-item">
                    <div class="d-flex justify-content-between align-items-start">
                        <div>
                            <h6 class="mb-1 small">${doc.fileName}</h6>
                            <p class="mb-1 small text-muted">
                                <i class="bi bi-key-fill"></i> ${doc.signatureMetadata.keyName || 'Unknown Key'}
                            </p>
                            <small class="text-muted">
                                ${doc.signatureMetadata.provider || 'Unknown Provider'} • ${signedAt}
                            </small>
                        </div>
                        <div class="btn-group-vertical" role="group">
                            <button class="btn btn-outline-success btn-sm" onclick="downloadSignedDocument('${doc._id}')">
                                <i class="bi bi-download"></i>
                            </button>
                            <button class="btn btn-outline-danger btn-sm" onclick="deleteSignedDocument('${doc._id}')">
                                <i class="bi bi-trash"></i>
                            </button>
                        </div>
                    </div>
                </div>
            `;
        });
        
        html += '</div></div>';
    }
    
    // Detached signatures section
    if (detached.length > 0) {
        html += `
            <div class="col-md-6">
                <h6><i class="bi bi-file-earmark-code text-info"></i> Detached Signatures (${detached.length})</h6>
                <div class="list-group mb-3">
        `;
        
        detached.forEach(doc => {
            const signedAt = new Date(doc.signatureId.signedAt).toLocaleDateString();
            html += `
                <div class="list-group-item">
                    <div class="d-flex justify-content-between align-items-start">
                        <div>
                            <h6 class="mb-1 small">${doc.fileName}</h6>
                            <p class="mb-1 small text-muted">
                                <i class="bi bi-key-fill"></i> ${doc.signatureMetadata.keyName || 'Unknown Key'}
                            </p>
                            <small class="text-muted">
                                ${doc.signatureMetadata.provider || 'Unknown Provider'} • ${signedAt}
                            </small>
                        </div>
                        <div class="btn-group-vertical" role="group">
                            <button class="btn btn-outline-success btn-sm" onclick="downloadSignedDocument('${doc._id}')">
                                <i class="bi bi-download"></i>
                            </button>
                            <button class="btn btn-outline-danger btn-sm" onclick="deleteSignedDocument('${doc._id}')">
                                <i class="bi bi-trash"></i>
                            </button>
                        </div>
                    </div>
                </div>
            `;
        });
        
        html += '</div></div>';
    }
    
    html += '</div>';
    
    if (embedded.length === 0 && detached.length === 0) {
        html = `
            <div class="text-center py-4">
                <i class="bi bi-info-circle display-4 text-muted mb-3"></i>
                <h6 class="text-muted">Processing Signed Documents</h6>
                <p class="text-muted">Signed documents are being prepared...</p>
            </div>
        `;
    }
    
    container.innerHTML = html;
}

async function downloadSignedDocument(signedDocId) {
    try {
        const response = await fetch(`/api/signeddocuments/${signedDocId}/download`);
        
        if (!response.ok) {
            throw new Error('Failed to download signed document');
        }
        
        // Get filename from Content-Disposition header
        const contentDisposition = response.headers.get('Content-Disposition');
        let fileName = 'signed-document.txt';
        if (contentDisposition) {
            const matches = contentDisposition.match(/filename="(.+)"/);
            if (matches && matches[1]) {
                fileName = matches[1];
            }
        }
        
        const blob = await response.blob();
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.style.display = 'none';
        a.href = url;
        a.download = fileName;
        
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
        document.body.removeChild(a);
        
        showNotification(`Downloaded: ${fileName}`, 'success');
        
    } catch (error) {
        console.error('Error downloading signed document:', error);
        showNotification(error.message, 'danger');
    }
}

async function deleteSignedDocument(signedDocId) {
    if (!confirm('Are you sure you want to delete this signed document? This action cannot be undone.')) {
        return;
    }
    
    try {
        const response = await fetch(`/api/signeddocuments/${signedDocId}`, {
            method: 'DELETE'
        });
        
        const result = await response.json();
        
        if (response.ok) {
            showNotification('Signed document deleted successfully', 'success');
            loadSignedDocuments(); // Refresh the list
        } else {
            throw new Error(result.error || 'Failed to delete signed document');
        }
        
    } catch (error) {
        console.error('Error deleting signed document:', error);
        showNotification(error.message, 'danger');
    }
}

function refreshSignedDocuments() {
    loadSignedDocuments();
}

// Export functions for external use
window.TPMDocumentDetail = {
    verifySignature,
    showSignatureDetails,
    downloadDocument,
    confirmDelete,
    confirmDeleteSignature,
    copyToClipboard,
    showNotification,
    loadSignedDocuments,
    downloadSignedDocument,
    deleteSignedDocument,
    refreshSignedDocuments
};