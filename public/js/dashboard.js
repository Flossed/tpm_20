// Dashboard functionality for TPM 2.0 Application

document.addEventListener('DOMContentLoaded', function() {
    initializeDashboard();
    loadDashboardStats();
    loadRecentActivity();
});

function initializeDashboard() {
    console.log('TPM 2.0 Dashboard initialized');
    
    // Add click handlers for quick action cards
    const quickActionCards = document.querySelectorAll('.quick-action-card');
    quickActionCards.forEach(card => {
        card.addEventListener('click', function() {
            const action = this.dataset.action;
            handleQuickAction(action);
        });
    });
    
    // Add hover effects
    quickActionCards.forEach(card => {
        card.addEventListener('mouseenter', function() {
            this.style.transform = 'translateY(-2px)';
            this.style.boxShadow = '0 4px 8px rgba(0,0,0,0.1)';
        });
        
        card.addEventListener('mouseleave', function() {
            this.style.transform = 'translateY(0)';
            this.style.boxShadow = '0 2px 4px rgba(0,0,0,0.05)';
        });
    });
}

function handleQuickAction(action) {
    switch(action) {
        case 'create-key':
            window.location.href = '/keys';
            break;
        case 'upload-document':
            window.location.href = '/documents';
            break;
        case 'view-keys':
            window.location.href = '/keys';
            break;
        case 'view-documents':
            window.location.href = '/documents';
            break;
        default:
            console.log('Unknown action:', action);
    }
}

async function loadDashboardStats() {
    try {
        // Load key statistics
        const keyStats = await fetchKeyStatistics();
        updateKeyStats(keyStats);
        
        // Load document statistics
        const docStats = await fetchDocumentStatistics();
        updateDocumentStats(docStats);
        
        // Load signature statistics
        const sigStats = await fetchSignatureStatistics();
        updateSignatureStats(sigStats);
        
    } catch (error) {
        console.error('Error loading dashboard statistics:', error);
        showNotification('Warning: Could not load dashboard statistics', 'warning');
    }
}

async function fetchKeyStatistics() {
    try {
        const response = await fetch('/api/keys/stats');
        if (response.ok) {
            return await response.json();
        }
        return { activeKeys: 0, totalKeys: 0 };
    } catch (error) {
        console.error('Error fetching key statistics:', error);
        return { activeKeys: 0, totalKeys: 0 };
    }
}

async function fetchDocumentStatistics() {
    try {
        const response = await fetch('/api/documents/stats');
        if (response.ok) {
            return await response.json();
        }
        return { totalDocuments: 0, totalSize: 0 };
    } catch (error) {
        console.error('Error fetching document statistics:', error);
        return { totalDocuments: 0, totalSize: 0 };
    }
}

async function fetchSignatureStatistics() {
    try {
        const response = await fetch('/api/signatures/stats');
        if (response.ok) {
            return await response.json();
        }
        return { totalSignatures: 0, validSignatures: 0 };
    } catch (error) {
        console.error('Error fetching signature statistics:', error);
        return { totalSignatures: 0, validSignatures: 0 };
    }
}

function updateKeyStats(stats) {
    const activeKeysElement = document.getElementById('activeKeys');
    const totalKeysElement = document.getElementById('totalKeys');
    
    if (activeKeysElement) {
        activeKeysElement.textContent = stats.activeKeys || '0';
    }
    if (totalKeysElement) {
        totalKeysElement.textContent = stats.totalKeys || '0';
    }
}

function updateDocumentStats(stats) {
    const totalDocsElement = document.getElementById('totalDocuments');
    const totalSizeElement = document.getElementById('totalSize');
    
    if (totalDocsElement) {
        totalDocsElement.textContent = stats.totalDocuments || '0';
    }
    if (totalSizeElement) {
        const sizeInMB = ((stats.totalSize || 0) / 1024 / 1024).toFixed(2);
        totalSizeElement.textContent = `${sizeInMB} MB`;
    }
}

function updateSignatureStats(stats) {
    const totalSigsElement = document.getElementById('totalSignatures');
    const validSigsElement = document.getElementById('validSignatures');
    
    if (totalSigsElement) {
        totalSigsElement.textContent = stats.totalSignatures || '0';
    }
    if (validSigsElement) {
        validSigsElement.textContent = stats.validSignatures || '0';
    }
}

async function loadRecentActivity() {
    try {
        const response = await fetch('/api/activity/recent');
        if (response.ok) {
            const activities = await response.json();
            displayRecentActivity(activities);
        }
    } catch (error) {
        console.error('Error loading recent activity:', error);
    }
}

function displayRecentActivity(activities) {
    const activityContainer = document.getElementById('recentActivity');
    if (!activityContainer) return;
    
    if (!activities || activities.length === 0) {
        activityContainer.innerHTML = '<p class="text-muted">No recent activity</p>';
        return;
    }
    
    const activityHtml = activities.map(activity => `
        <div class="activity-item d-flex align-items-center mb-3">
            <div class="activity-icon me-3">
                <i class="bi ${getActivityIcon(activity.type)} text-primary"></i>
            </div>
            <div class="activity-details flex-grow-1">
                <div class="activity-text">${activity.description}</div>
                <small class="text-muted">${formatTimeAgo(activity.timestamp)}</small>
            </div>
        </div>
    `).join('');
    
    activityContainer.innerHTML = activityHtml;
}

function getActivityIcon(activityType) {
    const icons = {
        'key_created': 'bi-key-fill',
        'document_uploaded': 'bi-file-earmark-plus',
        'document_signed': 'bi-pen-fill',
        'signature_verified': 'bi-shield-check',
        'key_deleted': 'bi-key',
        'default': 'bi-activity'
    };
    return icons[activityType] || icons.default;
}

function formatTimeAgo(timestamp) {
    const now = new Date();
    const past = new Date(timestamp);
    const diffInSeconds = Math.floor((now - past) / 1000);
    
    if (diffInSeconds < 60) return 'Just now';
    if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)} minutes ago`;
    if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)} hours ago`;
    return `${Math.floor(diffInSeconds / 86400)} days ago`;
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

// Refresh dashboard data every 30 seconds
setInterval(() => {
    loadDashboardStats();
    loadRecentActivity();
}, 30000);

// Export functions for external use
window.TPMDashboard = {
    loadDashboardStats,
    loadRecentActivity,
    showNotification
};