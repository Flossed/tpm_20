// Document Management functionality for TPM 2.0 Application

document.addEventListener('DOMContentLoaded', function() {
    initializeDocumentManagement();
    loadDocumentsList();
});

function initializeDocumentManagement() {
    console.log('TPM Document Management initialized');
    
    // Initialize file upload functionality
    initializeFileUpload();
    
    // Initialize document actions
    initializeDocumentActions();
    
    // Initialize file type filter
    initializeFileTypeFilter();
}

function initializeFileUpload() {
    const uploadBtn = document.getElementById('uploadBtn');
    const uploadForm = document.getElementById('uploadDocumentForm');
    const fileInput = document.getElementById('document');
    const filePreview = document.getElementById('filePreview');
    
    if (uploadBtn) {
        uploadBtn.addEventListener('click', function() {
            const modal = new bootstrap.Modal(document.getElementById('uploadDocumentModal'));
            modal.show();
        });
    }
    
    if (fileInput) {
        fileInput.addEventListener('change', handleFileSelect);
    }
    
    if (uploadForm) {
        uploadForm.addEventListener('submit', handleFileUpload);
    }
}

function handleFileSelect(event) {
    const file = event.target.files[0];
    const filePreview = document.getElementById('filePreview');
    const previewContent = document.getElementById('previewContent');
    const uploadBtn = document.getElementById('uploadBtn');
    
    if (!file) {
        if (filePreview) filePreview.classList.add('d-none');
        if (uploadBtn) uploadBtn.disabled = true;
        return;
    }
    
    // Validate file type
    const allowedTypes = ['.txt', '.md', '.json'];
    const fileExtension = file.name.toLowerCase().substring(file.name.lastIndexOf('.'));
    
    if (!allowedTypes.includes(fileExtension)) {
        showNotification('Invalid file type. Only .txt, .md, and .json files are allowed.', 'danger');
        event.target.value = '';
        if (uploadBtn) uploadBtn.disabled = true;
        return;
    }
    
    // Validate file size (10MB limit)
    if (file.size > 10 * 1024 * 1024) {
        showNotification('File size too large. Maximum size is 10MB.', 'danger');
        event.target.value = '';
        if (uploadBtn) uploadBtn.disabled = true;
        return;
    }
    
    // Enable upload button
    if (uploadBtn) uploadBtn.disabled = false;
    
    // Update file preview info
    const previewFileName = document.getElementById('previewFileName');
    const previewFileSize = document.getElementById('previewFileSize');
    const previewFileType = document.getElementById('previewFileType');
    
    if (previewFileName) previewFileName.textContent = file.name;
    if (previewFileSize) previewFileSize.textContent = (file.size / 1024).toFixed(2) + ' KB';
    if (previewFileType) previewFileType.textContent = fileExtension.substring(1).toUpperCase();
    
    // Read and preview file content
    const reader = new FileReader();
    reader.onload = function(e) {
        const content = e.target.result;
        
        if (previewContent) {
            // Truncate long content for preview
            const preview = content.length > 500 ? content.substring(0, 500) + '...' : content;
            previewContent.textContent = preview;
        }
        
        if (filePreview) {
            filePreview.classList.remove('d-none');
        }
    };
    
    reader.readAsText(file);
}

async function handleFileUpload(e) {
    e.preventDefault();
    
    const form = e.target;
    const submitBtn = form.querySelector('button[type="submit"]');
    const originalText = submitBtn.textContent;
    const fileInput = document.getElementById('document');
    const uploadedByInput = document.getElementById('uploadedBy');
    
    if (!fileInput || !fileInput.files[0]) {
        showNotification('Please select a file to upload', 'warning');
        return;
    }
    
    try {
        submitBtn.disabled = true;
        submitBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Uploading...';
        
        const formData = new FormData();
        formData.append('document', fileInput.files[0]);
        formData.append('uploadedBy', uploadedByInput ? uploadedByInput.value : 'user');
        
        const response = await fetch('/api/documents', {
            method: 'POST',
            body: formData
        });
        
        const result = await response.json();
        
        if (response.ok) {
            showNotification('Document uploaded successfully!', 'success');
            
            // Close modal and reset form
            const modal = bootstrap.Modal.getInstance(document.getElementById('uploadDocumentModal'));
            modal.hide();
            form.reset();
            document.getElementById('filePreview').style.display = 'none';
            
            // Refresh documents list
            await loadDocumentsList();
        } else {
            throw new Error(result.error || 'Failed to upload document');
        }
        
    } catch (error) {
        console.error('Error uploading document:', error);
        showNotification(error.message, 'danger');
    } finally {
        submitBtn.disabled = false;
        submitBtn.textContent = originalText;
    }
}

async function loadDocumentsList() {
    try {
        const response = await fetch('/api/documents');
        if (response.ok) {
            const documents = await response.json();
            displayDocumentsList(documents);
        } else {
            console.error('Failed to load documents');
        }
    } catch (error) {
        console.error('Error loading documents:', error);
        showNotification('Failed to load documents', 'warning');
    }
}

function displayDocumentsList(documents) {
    const documentsTableBody = document.querySelector('#documentsTable tbody');
    if (!documentsTableBody) return;
    
    if (!documents || documents.length === 0) {
        documentsTableBody.innerHTML = `
            <tr>
                <td colspan="6" class="text-center text-muted py-4">
                    <i class="bi bi-file-earmark fs-1 mb-2"></i>
                    <div>No documents found</div>
                    <small>Upload your first document to get started</small>
                </td>
            </tr>
        `;
        return;
    }
    
    const documentsHtml = documents.map(doc => `
        <tr data-document-id="${doc._id}">
            <td>
                <div class="d-flex align-items-center">
                    <i class="bi ${getFileTypeIcon(doc.fileType)} me-2 fs-5"></i>
                    <div>
                        <strong>${escapeHtml(doc.fileName)}</strong>
                        <br><small class="text-muted">${doc.hash.substring(0, 16)}...</small>
                    </div>
                </div>
            </td>
            <td>
                <span class="badge ${getFileTypeBadgeClass(doc.fileType)}">${doc.fileType.toUpperCase()}</span>
            </td>
            <td>${formatFileSize(doc.size)}</td>
            <td>${formatDate(doc.uploadedAt)}</td>
            <td>
                <span class="badge bg-secondary" id="sigCount-${doc._id}">Loading...</span>
            </td>
            <td>
                <div class="btn-group" role="group">
                    <button type="button" class="btn btn-sm btn-outline-primary" onclick="viewDocumentDetails('${doc._id}')">
                        <i class="bi bi-eye"></i>
                    </button>
                    <button type="button" class="btn btn-sm btn-outline-success" onclick="signDocument('${doc._id}')">
                        <i class="bi bi-pen"></i>
                    </button>
                    <button type="button" class="btn btn-sm btn-outline-danger" onclick="confirmDeleteDocument('${doc._id}', '${escapeHtml(doc.fileName)}')">
                        <i class="bi bi-trash"></i>
                    </button>
                </div>
            </td>
        </tr>
    `).join('');
    
    documentsTableBody.innerHTML = documentsHtml;
    
    // Load signature counts for each document
    documents.forEach(doc => loadSignatureCount(doc._id));
}

async function loadSignatureCount(documentId) {
    try {
        const response = await fetch(`/api/documents/${documentId}/signatures/count`);
        if (response.ok) {
            const result = await response.json();
            const countElement = document.getElementById(`sigCount-${documentId}`);
            if (countElement) {
                countElement.textContent = result.count || 0;
                countElement.className = result.count > 0 ? 'badge bg-success' : 'badge bg-secondary';
            }
        }
    } catch (error) {
        console.error('Error loading signature count:', error);
    }
}

function getFileTypeIcon(fileType) {
    const icons = {
        'text': 'bi-file-earmark-text',
        'markdown': 'bi-file-earmark-richtext',
        'json': 'bi-file-earmark-code'
    };
    return icons[fileType] || 'bi-file-earmark';
}

function getFileTypeBadgeClass(fileType) {
    const classes = {
        'text': 'bg-primary',
        'markdown': 'bg-info',
        'json': 'bg-warning text-dark'
    };
    return classes[fileType] || 'bg-secondary';
}

function initializeDocumentActions() {
    // Initialize delete modal
    const confirmDeleteBtn = document.getElementById('confirmDeleteDocumentBtn');
    if (confirmDeleteBtn) {
        confirmDeleteBtn.addEventListener('click', function() {
            const docId = this.dataset.documentId;
            if (docId) {
                handleDeleteDocument(docId);
            }
        });
    }
}

function initializeFileTypeFilter() {
    const filterSelect = document.getElementById('fileTypeFilter');
    if (filterSelect) {
        filterSelect.addEventListener('change', function() {
            const selectedType = this.value;
            filterDocumentsByType(selectedType);
        });
    }
}

function filterDocumentsByType(fileType) {
    const rows = document.querySelectorAll('#documentsTable tbody tr[data-document-id]');
    
    rows.forEach(row => {
        if (!fileType || fileType === 'all') {
            row.style.display = '';
        } else {
            const badge = row.querySelector('.badge');
            const rowType = badge ? badge.textContent.toLowerCase() : '';
            row.style.display = rowType === fileType ? '' : 'none';
        }
    });
}

function viewDocumentDetails(documentId) {
    window.location.href = `/documents/${documentId}`;
}

function signDocument(documentId) {
    window.location.href = `/documents/${documentId}/sign`;
}

function confirmDeleteDocument(documentId, fileName) {
    const modal = new bootstrap.Modal(document.getElementById('deleteDocumentModal'));
    const fileNameElement = document.getElementById('deleteDocumentName');
    const confirmBtn = document.getElementById('confirmDeleteDocumentBtn');
    
    if (fileNameElement) {
        fileNameElement.textContent = fileName;
    }
    
    if (confirmBtn) {
        confirmBtn.dataset.documentId = documentId;
    }
    
    modal.show();
}

async function handleDeleteDocument(documentId) {
    const confirmBtn = document.getElementById('confirmDeleteDocumentBtn');
    const originalText = confirmBtn.textContent;
    
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
            
            // Refresh documents list
            await loadDocumentsList();
        } else {
            throw new Error(result.error || 'Failed to delete document');
        }
        
    } catch (error) {
        console.error('Error deleting document:', error);
        showNotification(error.message, 'danger');
    } finally {
        confirmBtn.disabled = false;
        confirmBtn.textContent = originalText;
    }
}

// Utility functions
function formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function formatDate(dateString) {
    if (!dateString) return 'Unknown';
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
window.TPMDocuments = {
    loadDocumentsList,
    viewDocumentDetails,
    signDocument,
    confirmDeleteDocument,
    showNotification
};